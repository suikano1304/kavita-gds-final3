#!/usr/bin/env python3
"""Read-only Kavita-GDS scanner diagnostics.

The script never writes to the Kavita database or media folders. It summarizes
the failure modes that matter most for GDS scans:

- Pages=0 media rows
- duplicate MangaFile.FilePath rows
- MediaError distribution
- optional archive validation for Pages=0 archives
- optional source-cover/config-cache risk classification
"""

from __future__ import annotations

import argparse
import collections
import os
import sqlite3
import zipfile

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".avif"}
ARCHIVE_EXTENSIONS = {".zip", ".cbz", ".rar", ".cbr", ".7z", ".7zip", ".cb7", ".tar.gz", ".cbt"}


def connect_readonly(db_path: str) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    return con


def mapped_path(path: str, container_root: str, host_root: str) -> str:
    prefix = container_root.rstrip("/") + "/"
    if path.startswith(prefix):
        return host_root.rstrip("/") + "/" + path[len(prefix):]
    return path


def print_rows(title: str, rows: list[sqlite3.Row]) -> None:
    print(f"\n## {title}")
    if not rows:
        print("(none)")
        return
    for row in rows:
        print(dict(row))


def summarize_db(con: sqlite3.Connection) -> None:
    print_rows("libraries", list(con.execute("""
        select l.Id, l.Name, l.Type, l.EnableMetadata, l.AllowMetadataMatching, l.FolderWatching,
               count(distinct s.Id) as Series,
               count(distinct mf.Id) as Files,
               sum(case when mf.Pages = 0 then 1 else 0 end) as Pages0
        from Library l
        left join Series s on s.LibraryId = l.Id
        left join Volume v on v.SeriesId = s.Id
        left join Chapter c on c.VolumeId = v.Id
        left join MangaFile mf on mf.ChapterId = c.Id
        group by l.Id
        order by l.Id
    """)))

    print_rows("pages0 by library/ext", list(con.execute("""
        select l.Id as LibraryId, l.Name as LibraryName, lower(coalesce(mf.Extension, '')) as Ext, count(*) as Count
        from MangaFile mf
        join Chapter c on c.Id = mf.ChapterId
        join Volume v on v.Id = c.VolumeId
        join Series s on s.Id = v.SeriesId
        join Library l on l.Id = s.LibraryId
        where mf.Pages = 0
        group by l.Id, Ext
        order by l.Id, Count desc
    """)))

    print_rows("duplicate file paths by library/ext", list(con.execute("""
        with d as (
            select FilePath
            from MangaFile
            group by FilePath
            having count(*) > 1
        )
        select l.Id as LibraryId, l.Name as LibraryName, lower(coalesce(mf.Extension, '')) as Ext,
               count(distinct d.FilePath) as Groups,
               count(*) as RowRefs
        from d
        join MangaFile mf on mf.FilePath = d.FilePath
        join Chapter c on c.Id = mf.ChapterId
        join Volume v on v.Id = c.VolumeId
        join Series s on s.Id = v.SeriesId
        join Library l on l.Id = s.LibraryId
        group by l.Id, Ext
        order by l.Id, RowRefs desc
    """)))

    print_rows("media errors by ext/comment", list(con.execute("""
        select lower(coalesce(Extension, '')) as Ext,
               substr(coalesce(Comment, ''), 1, 100) as Comment,
               count(*) as Count
        from MediaError
        group by Ext, Comment
        order by Count desc
        limit 40
    """)))


def summarize_duplicate_structure(con: sqlite3.Connection) -> None:
    rows = list(con.execute("""
        with d as (
            select FilePath, count(*) as Cnt
            from MangaFile
            group by FilePath
            having count(*) > 1
        )
        select l.Id as LibraryId, mf.FilePath, mf.Pages, s.Id as SeriesId,
               v.Id as VolumeId, c.Id as ChapterId, c.Range as ChapterRange
        from d
        join MangaFile mf on mf.FilePath = d.FilePath
        join Chapter c on c.Id = mf.ChapterId
        join Volume v on v.Id = c.VolumeId
        join Series s on s.Id = v.SeriesId
        join Library l on l.Id = s.LibraryId
        order by l.Id, mf.FilePath
    """))
    by_path: dict[tuple[int, str], list[sqlite3.Row]] = collections.defaultdict(list)
    for row in rows:
        by_path[(row["LibraryId"], row["FilePath"])].append(row)

    summary: collections.Counter[tuple[int, int, int, int, int, int, int]] = collections.Counter()
    for (library_id, _), items in by_path.items():
        summary[(
            library_id,
            len(items),
            len({item["SeriesId"] for item in items}),
            len({item["VolumeId"] for item in items}),
            len({item["ChapterId"] for item in items}),
            len({item["ChapterRange"] for item in items}),
            len({item["Pages"] for item in items}),
        )] += 1

    print("\n## duplicate structure")
    print("(LibraryId, RowRefs, Series, Volumes, Chapters, Ranges, PageValues) -> Groups")
    if not summary:
        print("(none)")
        return
    for key, count in sorted(summary.items()):
        print(f"{key} -> {count}")


def summarize_pages0_archives(con: sqlite3.Connection, container_root: str, host_root: str) -> None:
    rows = list(con.execute("""
        select l.Id as LibraryId, lower(coalesce(mf.Extension, '')) as Ext, mf.FilePath
        from MangaFile mf
        join Chapter c on c.Id = mf.ChapterId
        join Volume v on v.Id = c.VolumeId
        join Series s on s.Id = v.SeriesId
        join Library l on l.Id = s.LibraryId
        where mf.Pages = 0 and lower(coalesce(mf.Extension, '')) in ('.zip', '.cbz')
        order by l.Id, Ext
    """))

    stats: dict[tuple[int, str], collections.Counter[str]] = collections.defaultdict(collections.Counter)
    for row in rows:
        key = (row["LibraryId"], row["Ext"])
        stats[key]["files"] += 1
        file_path = mapped_path(row["FilePath"], container_root, host_root)
        if not os.path.exists(file_path):
            stats[key]["missing"] += 1
            continue
        stats[key]["exists"] += 1
        try:
            with zipfile.ZipFile(file_path) as archive:
                for name in archive.namelist():
                    if name.endswith("/"):
                        continue
                    ext = os.path.splitext(name.lower())[1]
                    if ext in IMAGE_EXTENSIONS:
                        stats[key]["images"] += 1
                    elif ext in ARCHIVE_EXTENSIONS:
                        stats[key]["nested_archives"] += 1
                stats[key]["readable"] += 1
        except Exception:
            stats[key]["errors"] += 1

    print("\n## pages0 archive validation")
    if not stats:
        print("(none)")
        return
    for key, counter in sorted(stats.items()):
        print(key, dict(counter))


def summarize_cover_risk(con: sqlite3.Connection, container_root: str, host_root: str) -> None:
    rows = list(con.execute("""
        select l.Id as LibraryId, s.Id as SeriesId, s.FolderPath, s.CoverImage as SeriesCover,
               v.CoverImage as VolumeCover, c.CoverImage as ChapterCover
        from Series s
        join Library l on l.Id = s.LibraryId
        left join Volume v on v.SeriesId = s.Id
        left join Chapter c on c.VolumeId = v.Id
        where l.Type = 6
    """))

    series: dict[int, dict[str, object]] = {}
    for row in rows:
        item = series.setdefault(row["SeriesId"], {
            "library_id": row["LibraryId"],
            "folder": row["FolderPath"] or "",
            "series_cover": row["SeriesCover"] or "",
            "volume_covers": set(),
            "chapter_covers": set(),
        })
        if row["VolumeCover"]:
            item["volume_covers"].add(row["VolumeCover"])
        if row["ChapterCover"]:
            item["chapter_covers"].add(row["ChapterCover"])

    summary: collections.Counter[tuple[int, bool, bool]] = collections.Counter()
    risk_by_library: collections.Counter[int] = collections.Counter()
    for series_id, item in series.items():
        folder = mapped_path(str(item["folder"]), container_root, host_root)
        has_source_cover = any(os.path.exists(os.path.join(folder, name)) for name in ("cover.jpg", "cover.png", "cover.webp"))
        expected = {f"_s{series_id}.jpg", f"_s{series_id}.png", f"_s{series_id}.webp"}
        uses_expected_cache = (
            item["series_cover"] in expected
            or bool(item["volume_covers"] & expected)
            or bool(item["chapter_covers"] & expected)
        )
        library_id = int(item["library_id"])
        summary[(library_id, has_source_cover, uses_expected_cache)] += 1
        if uses_expected_cache and not has_source_cover:
            risk_by_library[library_id] += 1

    print("\n## cover source/cache risk")
    print("(LibraryId, HasSourceCover, UsesExpectedCacheName) -> Series")
    for key, count in sorted(summary.items()):
        print(f"{key} -> {count}")
    print("risk_by_library", dict(sorted(risk_by_library.items())))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", required=True, help="Path to kavita.db")
    parser.add_argument("--container-root", default="/mnt/gds", help="Media root stored in DB paths")
    parser.add_argument("--host-root", default="/mnt/gds2", help="Readable media root for this script")
    parser.add_argument("--check-archives", action="store_true", help="Open Pages=0 ZIP/CBZ files and classify contents")
    parser.add_argument("--check-covers", action="store_true", help="Check source cover files vs expected cache names")
    args = parser.parse_args()

    con = connect_readonly(args.db)
    print("integrity_check", con.execute("pragma integrity_check").fetchone()[0])
    summarize_db(con)
    summarize_duplicate_structure(con)
    if args.check_archives:
        summarize_pages0_archives(con, args.container_root, args.host_root)
    if args.check_covers:
        summarize_cover_risk(con, args.container_root, args.host_root)


if __name__ == "__main__":
    main()
