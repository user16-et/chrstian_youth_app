import { Body, Controller, Delete, Get, Headers, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { parseBearerToken, requireBearerToken } from '../../common/request-auth';
import { CreatePostDto } from './dto/create-post.dto';
import { PostsService } from './posts.service';

@ApiTags('posts')
@Controller('/posts')
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Get('/status')
  status() {
    return this.postsService.status();
  }

  @ApiOperation({ summary: 'List feed posts' })
  @Get()
  list(@Headers('authorization') authorization?: string) {
    return this.postsService.list(authorization ? requireBearerToken(authorization) : undefined);
  }

  @ApiOperation({ summary: 'Get a single post' })
  @Get('/:id')
  getById(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.postsService.getById(parseBearerToken(authorization) ?? undefined, id);
  }

  @ApiBearerAuth()
  @ApiBody({ type: CreatePostDto })
  @ApiOperation({ summary: 'Create a post as the authenticated user' })
  @Post()
  create(@Headers('authorization') authorization: string | undefined, @Body() body: CreatePostDto) {
    return this.postsService.create(requireBearerToken(authorization), body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Like a post' })
  @Post('/:id/like')
  like(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.postsService.like(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Unlike a post' })
  @Delete('/:id/like')
  unlike(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.postsService.unlike(requireBearerToken(authorization), id);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Share a post' })
  @Post('/:id/share')
  share(@Headers('authorization') authorization: string | undefined, @Param('id') id: string) {
    return this.postsService.share(requireBearerToken(authorization), id);
  }

  @ApiOperation({ summary: 'List comments for a post' })
  @Get('/:id/comments')
  comments(@Param('id') id: string) {
    return this.postsService.comments(id);
  }

  @ApiBearerAuth()
  @ApiBody({ schema: { type: 'object', properties: { body: { type: 'string' } }, required: ['body'] } })
  @ApiOperation({ summary: 'Comment on a post' })
  @Post('/:id/comments')
  comment(
    @Headers('authorization') authorization: string | undefined,
    @Param('id') id: string,
    @Body('body') body: string,
  ) {
    return this.postsService.addComment(requireBearerToken(authorization), id, { body });
  }

  @ApiBearerAuth()
  @Post("/:id/reactions")
  react(@Headers("authorization") authorization: string | undefined, @Param("id") id: string, @Body("reaction") reaction: string) {
    return this.postsService.react(requireBearerToken(authorization), id, reaction);
  }

  @ApiBearerAuth()
  @Post("/:id/comments/:commentId/replies")
  reply(@Headers("authorization") authorization: string | undefined, @Param("id") id: string, @Param("commentId") commentId: string, @Body("body") body: string) {
    return this.postsService.reply(requireBearerToken(authorization), id, commentId, body);
  }

  @ApiBearerAuth()
  @Post("/:id/repost")
  repost(@Headers("authorization") authorization: string | undefined, @Param("id") id: string, @Body() body: { caption?: string; language?: string }) {
    return this.postsService.repost(requireBearerToken(authorization), id, body.caption ?? "", body.language ?? "en");
  }

  @ApiBearerAuth()
  @Post("/:id/poll-votes")
  vote(@Headers("authorization") authorization: string | undefined, @Param("id") id: string, @Body("optionIndex") optionIndex: number) {
    return this.postsService.vote(requireBearerToken(authorization), id, optionIndex);
  }
}
