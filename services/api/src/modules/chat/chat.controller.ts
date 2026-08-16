import { Body, Controller, Get, Headers, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { CreateChatMessageDto } from './dto/create-chat-message.dto';
import { ChatService } from './chat.service';

@ApiTags('chat')
@Controller('/chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('/status')
  status() {
    return this.chatService.status();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List chat messages' })
  @Get('/messages')
  messages(@Headers('authorization') authorization: string | undefined, @Query('room') room?: string) {
    return this.chatService.listMessages(requireBearerToken(authorization), room);
  }

  @ApiBearerAuth()
  @ApiBody({ type: CreateChatMessageDto })
  @ApiOperation({ summary: 'Send a chat message as the authenticated user' })
  @Post('/messages')
  send(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: CreateChatMessageDto,
    @Query('room') room?: string,
  ) {
    return this.chatService.sendMessage(requireBearerToken(authorization), { body: body.body, room });
  }
}
