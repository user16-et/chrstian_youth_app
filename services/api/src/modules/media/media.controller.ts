import { Body, Controller, Get, Headers, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { CompleteUploadDto } from './dto/complete-upload.dto';
import { CreateUploadUrlDto } from './dto/create-upload-url.dto';
import { MediaService } from './media.service';

@ApiTags('media')
@ApiBearerAuth()
@Controller('/media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @ApiBody({ type: CreateUploadUrlDto })
  @ApiOperation({ summary: 'Create a direct-to-object-storage signed upload URL' })
  @Post('/upload-url')
  createUploadUrl(@Headers('authorization') authorization: string | undefined, @Body() body: CreateUploadUrlDto) {
    return this.media.createUploadUrl(requireBearerToken(authorization), body);
  }

  @ApiOperation({ summary: 'List media assets owned by the authenticated user' })
  @Get('/me')
  listMine(@Headers('authorization') authorization: string | undefined) {
    return this.media.listMine(requireBearerToken(authorization));
  }

  @ApiOperation({ summary: 'Get one media asset owned by the authenticated user' })
  @Get('/:assetId')
  getAsset(@Headers('authorization') authorization: string | undefined, @Param('assetId') assetId: string) {
    return this.media.getAsset(requireBearerToken(authorization), assetId);
  }

  @ApiBody({ type: CompleteUploadDto })
  @ApiOperation({ summary: 'Mark a direct upload complete after the client uploads to object storage' })
  @Post('/:assetId/complete')
  completeUpload(
    @Headers('authorization') authorization: string | undefined,
    @Param('assetId') assetId: string,
    @Body() body: CompleteUploadDto,
  ) {
    return this.media.completeUpload(requireBearerToken(authorization), assetId, body);
  }
}
