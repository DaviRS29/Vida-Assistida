import { Controller, Get } from '@nestjs/common';
import { Public } from './common/decorators/public.decorator';

@Controller()
export class AppController {
  @Public()
  @Get()
  getHealth() {
    return {
      name: 'Vida Assistida API',
      status: 'ok',
      timestamp: new Date().toISOString(),
    };
  }
}
