import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { User, UserRole } from '../users/entities/user.entity';
import { CreatePatientDto, UpdatePatientDto } from './dto/create-patient.dto';
import { JoinPatientDto } from './dto/join-patient.dto';
import { UpdateMemberDto } from './dto/member.dto';
import { PatientsService } from './patients.service';

@ApiTags('Pacientes')
@ApiBearerAuth()
@Controller('patients')
export class PatientsController {
  constructor(private readonly patientsService: PatientsService) {}

  @Get()
  list(@CurrentUser() user: User) {
    return this.patientsService.listFor(user);
  }

  @Public()
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @Post('invite/validate')
  validateInvite(@Body() dto: JoinPatientDto) {
    return this.patientsService.validateInvite(dto.code);
  }

  @Post('join')
  @Roles(UserRole.PROFESSIONAL)
  join(@Body() dto: JoinPatientDto, @CurrentUser() user: User) {
    return this.patientsService.join(dto, user);
  }

  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    return this.patientsService.getView(id, user);
  }

  @Patch(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePatientDto,
    @CurrentUser() user: User,
  ) {
    return this.patientsService.update(id, dto, user);
  }

  @Post(':id/invite-code')
  @Roles(UserRole.RESPONSIBLE)
  rotateInviteCode(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
  ) {
    return this.patientsService.rotateInviteCode(id, user);
  }

  @Get(':id/members')
  @Roles(UserRole.RESPONSIBLE)
  members(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    return this.patientsService.listMembers(id, user);
  }

  @Patch(':id/members/:memberId')
  @Roles(UserRole.RESPONSIBLE)
  updateMember(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Body() dto: UpdateMemberDto,
    @CurrentUser() user: User,
  ) {
    return this.patientsService.updateMember(id, memberId, dto, user);
  }

  @Delete(':id/members/:memberId')
  @Roles(UserRole.RESPONSIBLE)
  removeMember(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @CurrentUser() user: User,
  ) {
    return this.patientsService.removeMember(id, memberId, user);
  }

  @Post()
  @Roles(UserRole.RESPONSIBLE)
  create(@Body() dto: CreatePatientDto, @CurrentUser() user: User) {
    return this.patientsService.create(dto, user);
  }
}
