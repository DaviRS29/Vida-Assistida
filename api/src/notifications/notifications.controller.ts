import {
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { NotificationsService } from './notifications.service';

@ApiTags('Notificações')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Get()
  list(@CurrentUser() user: User) {
    return this.service.list(user);
  }

  @Post('read-all')
  markAll(@CurrentUser() user: User) {
    return this.service.markAll(user);
  }

  @Post(':id/read')
  async markRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
  ) {
    const items = await this.service.list(user);
    if (!items.some((item) => item.id === id)) {
      throw new ForbiddenException('Notificação indisponível.');
    }
    return this.service.markRead(user, id);
  }
}
