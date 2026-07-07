import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { ContentRepository } from '../../common/content.repository';
import { UserRepository } from '../../common/user.repository';
import { CreateBibleNoteDto } from './dto/create-bible-note.dto';
import { UpdateBibleNoteDto } from './dto/update-bible-note.dto';
import { BibleRepository } from './bible.repository';

@Injectable()
export class BibleService {
  constructor(
    private readonly contentRepository: ContentRepository,
    private readonly userRepository: UserRepository,
    private readonly bibleRepository: BibleRepository,
  ) {}

  async home(token: string | null) {
    const actor = token ? await this.userRepository.authenticate(token) : null;
    return this.bibleRepository.home(actor?.id ?? null);
  }

  versions() {
    return this.bibleRepository.versions();
  }

  books() {
    return this.bibleRepository.books();
  }

  async chapter(token: string | null, version: string, book: string, chapter: number) {
    const actor = token ? await this.userRepository.authenticate(token) : null;
    return this.bibleRepository.chapter(actor?.id ?? null, version || 'kjv', book || 'Romans', chapter || 8);
  }

  compare(reference: string, versions: string) {
    return this.bibleRepository.compare(reference || 'John 3:16', versions.split(',').map((item) => item.trim()).filter(Boolean));
  }

  listNotes(token: string) {
    return this.requireActor(token).then((actor) => this.contentRepository.listBibleNotes(actor.id));
  }

  listDailyVerses() {
    return this.contentRepository.listDailyVerses();
  }

  listReadingPlans() {
    return this.contentRepository.listReadingPlans();
  }

  search(query: string, token: string | null) {
    if (!query.trim()) {
      return [];
    }
    if (token) {
      return this.userRepository.authenticate(token).then((actor) => this.bibleRepository.search(query, actor?.id ?? null));
    }
    return this.bibleRepository.search(query, null);
  }

  async updateSettings(token: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.updateSettings(actor.id, input);
  }

  async joinPlan(token: string, planId: string) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.joinPlan(actor.id, planId);
  }

  async completePlanDay(token: string, planId: string, dayNumber: number) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.completePlanDay(actor.id, planId, dayNumber);
  }

  async createJournal(token: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.createJournal(actor.id, input);
  }

  async addMemoryVerse(token: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.addMemoryVerse(actor.id, input);
  }

  async createVerseCard(token: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.createVerseCard(actor.id, input);
  }

  async shareVerse(token: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.shareVerse(actor.id, input);
  }

  async createGroupStudy(token: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.createGroupStudy(actor.id, input);
  }

  async addGroupStudyNote(token: string, studyId: string, input: Record<string, unknown>) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.addGroupStudyNote(actor.id, studyId, input);
  }

  async analytics(token: string) {
    const actor = await this.requireActor(token);
    return this.bibleRepository.analytics(actor.id);
  }

  async listBookmarks(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listBibleBookmarks(actor.id);
  }

  async createBookmark(token: string, input: { reference: string; verseText: string; language: 'en' | 'am' }) {
    const actor = await this.requireActor(token);
    return this.contentRepository.createBibleBookmark({
      userId: actor.id,
      reference: input.reference,
      verseText: input.verseText,
      language: input.language,
    });
  }

  async deleteBookmark(token: string, bookmarkId: string) {
    const actor = await this.requireActor(token);
    const deleted = await this.contentRepository.deleteBibleBookmark(bookmarkId, actor.id);
    if (!deleted) {
      throw new NotFoundException('bible_bookmark_not_found');
    }
    return { id: bookmarkId, status: 'deleted' };
  }

  async listHighlights(token: string) {
    const actor = await this.requireActor(token);
    return this.contentRepository.listBibleHighlights(actor.id);
  }

  async createHighlight(token: string, input: { reference: string; verseText: string; color: string; note: string; language: 'en' | 'am' }) {
    const actor = await this.requireActor(token);
    return this.contentRepository.createBibleHighlight({
      userId: actor.id,
      reference: input.reference,
      verseText: input.verseText,
      color: input.color,
      note: input.note,
      language: input.language,
    });
  }

  async deleteHighlight(token: string, highlightId: string) {
    const actor = await this.requireActor(token);
    const deleted = await this.contentRepository.deleteBibleHighlight(highlightId, actor.id);
    if (!deleted) {
      throw new NotFoundException('bible_highlight_not_found');
    }
    return { id: highlightId, status: 'deleted' };
  }

  async createNote(token: string, input: CreateBibleNoteDto) {
    const actor = await this.requireActor(token);
    return this.contentRepository.createBibleNote({
      userId: actor.id,
      reference: input.reference,
      verseText: input.verseText ?? '',
      note: input.note,
      language: input.language,
    });
  }

  async updateNote(token: string, noteId: string, input: UpdateBibleNoteDto) {
    const actor = await this.requireActor(token);
    const updated = await this.contentRepository.updateBibleNote({
      noteId,
      userId: actor.id,
      reference: input.reference,
      verseText: input.verseText ?? '',
      note: input.note,
      language: input.language,
    });
    if (!updated) {
      throw new NotFoundException('bible_note_not_found');
    }
    return updated;
  }

  async deleteNote(token: string, noteId: string) {
    const actor = await this.requireActor(token);
    const deleted = await this.contentRepository.deleteBibleNote(noteId, actor.id);
    if (!deleted) {
      throw new NotFoundException('bible_note_not_found');
    }
    return { id: noteId, status: 'deleted' };
  }

  private async requireActor(token: string) {
    const actor = await this.userRepository.authenticate(token);
    if (!actor) {
      throw new BadRequestException('authenticated_user_not_found');
    }
    return actor;
  }
}
