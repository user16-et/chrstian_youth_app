import { Body, Controller, Get, Headers, Param, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation } from '@nestjs/swagger';

import { requireBearerToken } from '../../common/request-auth';
import { PaymentsService } from './payments.service';

@Controller('/payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Get('/status')
  status() {
    return this.payments.status();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Start a payment; returns a hosted checkout URL' })
  @Post('/checkout')
  checkout(@Headers('authorization') h: string | undefined, @Body() body: Record<string, unknown>) {
    return this.payments.checkout(requireBearerToken(h), body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Your gateway payment transactions' })
  @Get('/transactions')
  transactions(@Headers('authorization') h: string | undefined) {
    return this.payments.listTransactions(requireBearerToken(h));
  }

  @ApiOperation({ summary: 'Payment gateway webhook (signature-verified)' })
  @Post('/webhook')
  webhook(
    @Req() req: { rawBody?: Buffer },
    @Headers('chapa-signature') chapaSignature: string | undefined,
    @Headers('x-chapa-signature') xChapaSignature: string | undefined,
    @Body() body: Record<string, unknown>,
  ) {
    const raw = req.rawBody?.toString('utf8') ?? JSON.stringify(body ?? {});
    return this.payments.webhook(raw, chapaSignature ?? xChapaSignature, body ?? {});
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Verify/poll a transaction status' })
  @Get('/:txRef/verify')
  verify(@Headers('authorization') h: string | undefined, @Param('txRef') txRef: string) {
    return this.payments.verify(requireBearerToken(h), txRef);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Mock-only: mark a transaction paid (non-production)' })
  @Post('/:txRef/mock-complete')
  mockComplete(@Headers('authorization') h: string | undefined, @Param('txRef') txRef: string) {
    return this.payments.mockComplete(requireBearerToken(h), txRef);
  }
}
