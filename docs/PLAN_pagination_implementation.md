# Pagination-Based Reading Implementation Plan

## Overview
Replace the current scroll-based `SingleChildScrollView` + `MarkdownBody` chapter reader with a paginated `PageView.builder` system that measures exact per-block heights using `TextPainter` and uses greedy bin-packing for page layout.

## Architecture
```
Markdown String
     |
     v
MarkdownBlockParser --> List<MarkdownBlock> (typed blocks with RTL)
     |
     v
PageLayoutEngine.measure() --> List<double> blockHeights (via TextPainter)
     |
     v
PageLayoutEngine.paginate() --> List<List<int>> pages (block indices)
     |
     v
ChapterPage --> PageView.builder renders blocks per page
```

## Design Decisions
| Decision | Choice |
|----------|--------|
| RTL detection | Per-block Unicode range check |
| Block exceeding page height | Split at sentence boundaries |
| LibraryProgress schema | Repurpose pageIndex to store first block index |
| Page navigation | Integrated into bottom bar beside font controls |

## Files to Create
1. `lib/utils/markdown_block.dart` - MarkdownBlock model
2. `lib/utils/markdown_block_parser.dart` - Parse markdown into typed blocks
3. `lib/utils/page_layout_engine.dart` - Measurement + pagination engine

## Files to Modify
4. `lib/pages/chapter_page.dart` - Major rewrite for pagination
5. `lib/pages/library_page.dart` - Minor updates for progress display
