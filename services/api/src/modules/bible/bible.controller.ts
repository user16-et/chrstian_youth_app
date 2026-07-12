import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { CreateBibleNoteDto } from './dto/create-bible-note.dto';
import { UpdateBibleNoteDto } from './dto/update-bible-note.dto';
import { BibleService } from './bible.service';

@ApiTags('bible')
@Controller('/')
export class BibleController {
  constructor(private readonly bibleService: BibleService) {}

  @ApiOperation({ summary: 'Get the complete Bible study dashboard' })
  @Get('/bible/home')
  home(@Headers('authorization') authorization?: string) {
    return this.bibleService.home(authorization ? requireBearerToken(authorization) : null);
  }

  @ApiOperation({ summary: 'List Bible versions' })
  @Get('/bible/versions')
  versions() {
    return this.bibleService.versions();
  }

  @ApiOperation({ summary: 'List Bible books' })
  @Get('/bible/books')
  books() {
    return this.bibleService.books();
  }

  @ApiOperation({ summary: 'Read a Bible chapter' })
  @Get('/bible/reader')
  reader(
    @Query('version') version?: string,
    @Query('book') book?: string,
    @Query('chapter') chapter?: string,
    @Headers('authorization') authorization?: string,
  ) {
    return this.bibleService.chapter(authorization ? requireBearerToken(authorization) : null, version ?? 'kjv', book ?? 'Romans', Number(chapter ?? 8));
  }

  @ApiOperation({ summary: 'Download an entire translation for offline use' })
  @Get('/bible/download/:version')
  download(@Param('version') version: string) {
    return this.bibleService.download(version);
  }

  @ApiOperation({ summary: 'Compare a verse across translations' })
  @Get('/bible/compare')
  compare(@Query('reference') reference?: string, @Query('versions') versions?: string) {
    return this.bibleService.compare(reference ?? 'John 3:16', versions ?? 'kjv,amh');
  }

  @ApiOperation({ summary: 'List daily verses' })
  @Get('/bible/daily-verses')
  dailyVerses() {
    return this.bibleService.listDailyVerses();
  }

  @ApiOperation({ summary: 'List reading plans' })
  @Get('/bible/plans')
  readingPlans() {
    return this.bibleService.listReadingPlans();
  }

  @ApiOperation({ summary: 'Search Bible content' })
  @Get('/bible/search')
  search(@Query('q') query?: string, @Query('version') version?: string, @Headers('authorization') authorization?: string) {
    return this.bibleService.search(query ?? '', authorization ? requireBearerToken(authorization) : null, version ?? null);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update Bible settings' })
  @Post('/bible/settings')
  updateSettings(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.bibleService.updateSettings(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Join a Bible reading plan' })
  @Post('/bible/plans/:id/join')
  joinPlan(@Headers('authorization') authorization?: string, @Param('id') planId?: string) {
    return this.bibleService.joinPlan(requireBearerToken(authorization), planId ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Complete a Bible reading plan day' })
  @Post('/bible/plans/:id/progress')
  completePlanDay(
    @Headers('authorization') authorization?: string,
    @Param('id') planId?: string,
    @Body() body?: { dayNumber?: number },
  ) {
    return this.bibleService.completePlanDay(requireBearerToken(authorization), planId ?? '', Number(body?.dayNumber ?? 1));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a Bible study journal entry' })
  @Post('/bible/journal')
  createJournal(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.bibleService.createJournal(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Add a Bible memory verse' })
  @Post('/bible/memory')
  addMemoryVerse(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.bibleService.addMemoryVerse(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a designed verse card record' })
  @Post('/bible/verse-cards')
  createVerseCard(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.bibleService.createVerseCard(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Share a Bible verse to an app channel' })
  @Post('/bible/share')
  shareVerse(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.bibleService.shareVerse(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a group Bible study' })
  @Post('/bible/group-studies')
  createGroupStudy(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.bibleService.createGroupStudy(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Add a note to a group Bible study' })
  @Post('/bible/group-studies/:id/notes')
  addGroupStudyNote(
    @Headers('authorization') authorization?: string,
    @Param('id') studyId?: string,
    @Body() body?: Record<string, unknown>,
  ) {
    return this.bibleService.addGroupStudyNote(requireBearerToken(authorization), studyId ?? '', body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List the viewer\'s Bible study groups and discoverable ones' })
  @Get('/bible/study-groups')
  listStudyGroups(@Headers('authorization') authorization?: string) {
    return this.bibleService.listStudyGroups(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a Bible study group (a chat-enabled group)' })
  @Post('/bible/study-groups')
  createStudyGroup(@Headers('authorization') authorization?: string, @Body() body?: Record<string, unknown>) {
    return this.bibleService.createStudyGroup(requireBearerToken(authorization), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get Bible growth analytics' })
  @Get('/bible/analytics')
  analytics(@Headers('authorization') authorization?: string) {
    return this.bibleService.analytics(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List Bible bookmarks for the authenticated user' })
  @Get('/bible/bookmarks')
  bookmarks(@Headers('authorization') authorization?: string) {
    return this.bibleService.listBookmarks(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a Bible bookmark' })
  @Post('/bible/bookmarks')
  createBookmark(
    @Headers('authorization') authorization?: string,
    @Body() body?: { reference?: string; verseText?: string; language?: 'en' | 'am' },
  ) {
    return this.bibleService.createBookmark(requireBearerToken(authorization), {
      reference: body?.reference ?? '',
      verseText: body?.verseText ?? '',
      language: body?.language ?? 'en',
    });
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a Bible bookmark' })
  @Delete('/bible/bookmarks/:id')
  deleteBookmark(@Headers('authorization') authorization?: string, @Param('id') bookmarkId?: string) {
    return this.bibleService.deleteBookmark(requireBearerToken(authorization), bookmarkId ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List Bible highlights for the authenticated user' })
  @Get('/bible/highlights')
  highlights(@Headers('authorization') authorization?: string) {
    return this.bibleService.listHighlights(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a Bible highlight' })
  @Post('/bible/highlights')
  createHighlight(
    @Headers('authorization') authorization?: string,
    @Body() body?: { reference?: string; verseText?: string; color?: string; note?: string; language?: 'en' | 'am' },
  ) {
    return this.bibleService.createHighlight(requireBearerToken(authorization), {
      reference: body?.reference ?? '',
      verseText: body?.verseText ?? '',
      color: body?.color ?? 'gold',
      note: body?.note ?? '',
      language: body?.language ?? 'en',
    });
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a Bible highlight' })
  @Delete('/bible/highlights/:id')
  deleteHighlight(@Headers('authorization') authorization?: string, @Param('id') highlightId?: string) {
    return this.bibleService.deleteHighlight(requireBearerToken(authorization), highlightId ?? '');
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List Bible notes for the authenticated user' })
  @Get('/bible/notes')
  listNotes(@Headers('authorization') authorization?: string) {
    return this.bibleService.listNotes(requireBearerToken(authorization));
  }

  @ApiBearerAuth()
  @ApiBody({ type: CreateBibleNoteDto })
  @ApiOperation({ summary: 'Create a Bible note' })
  @Post('/bible/notes')
  createNote(@Headers('authorization') authorization?: string, @Body() body?: CreateBibleNoteDto) {
    return this.bibleService.createNote(requireBearerToken(authorization), body ?? { reference: '', verseText: '', note: '', language: 'en' });
  }

  @ApiBearerAuth()
  @ApiBody({ type: UpdateBibleNoteDto })
  @ApiOperation({ summary: 'Update a Bible note' })
  @Patch('/bible/notes/:id')
  updateNote(@Headers('authorization') authorization?: string, @Param('id') noteId?: string, @Body() body?: UpdateBibleNoteDto) {
    return this.bibleService.updateNote(requireBearerToken(authorization), noteId ?? '', body ?? { reference: '', verseText: '', note: '', language: 'en' });
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a Bible note' })
  @Delete('/bible/notes/:id')
  deleteNote(@Headers('authorization') authorization?: string, @Param('id') noteId?: string) {
    return this.bibleService.deleteNote(requireBearerToken(authorization), noteId ?? '');
  }
}
