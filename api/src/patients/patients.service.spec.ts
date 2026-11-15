import { ForbiddenException, GoneException } from '@nestjs/common';
import { PatientsService } from './patients.service';
import { UserRole } from '../users/entities/user.entity';

describe('PatientsService invitation rules', () => {
  const responsible = {
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Ana Souza',
    role: UserRole.RESPONSIBLE,
  } as any;
  const professional = {
    id: '22222222-2222-4222-8222-222222222222',
    name: 'Carlos Lima',
    role: UserRole.PROFESSIONAL,
  } as any;

  const repository = {
    findByJoinCode: jest.fn(),
    findMembership: jest.fn(),
    findAnyMembership: jest.fn(),
    findById: jest.fn(),
    countActiveMembers: jest.fn(async () => new Map()),
    touchMember: jest.fn(),
    save: jest.fn(async (patient) => patient),
  } as any;
  const audit = { record: jest.fn() } as any;
  const service = new PatientsService(repository, audit);

  beforeEach(() => jest.clearAllMocks());

  it('rejects an expired professional invitation', async () => {
    repository.findByJoinCode.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      inviteExpiresAt: new Date(Date.now() - 1000),
    });

    await expect(
      service.join({ code: 'VID-0000' }, professional),
    ).rejects.toBeInstanceOf(GoneException);
  });

  it('blocks a suspended professional from rejoining with the code', async () => {
    repository.findByJoinCode.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      inviteExpiresAt: new Date(Date.now() + 60_000),
    });
    repository.findAnyMembership.mockResolvedValue({ active: false });

    await expect(
      service.join({ code: 'VID-0000' }, professional),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('lets only the responsible owner rotate the invitation', async () => {
    const patient = {
      id: '33333333-3333-4333-8333-333333333333',
      responsibleId: responsible.id,
      responsible,
      joinCode: 'VIDA2026',
      inviteExpiresAt: new Date(),
    };
    repository.findById.mockResolvedValue(patient);

    const updated = await service.rotateInviteCode(patient.id, responsible);

    expect(updated.joinCode).toMatch(/^VID-[A-F0-9]{4}$/);
    expect(updated.responsibleName).toBe('Ana Souza');
    expect(audit.record).toHaveBeenCalledWith(
      responsible.id,
      patient.id,
      'patient.invite_rotated',
      'patient',
      patient.id,
      expect.objectContaining({ inviteExpiresAt: expect.any(String) }),
    );
  });

  it('hides the invitation code from professionals', async () => {
    const patient = {
      id: '33333333-3333-4333-8333-333333333333',
      responsibleId: responsible.id,
      responsible,
      joinCode: 'VIDA2026',
      inviteExpiresAt: new Date(),
    };
    repository.findById.mockResolvedValue(patient);
    repository.findMembership.mockResolvedValue({
      id: 'm1',
      active: true,
      lastAccessAt: new Date(),
      canViewMedications: true,
      canRecordMedications: true,
      canManageCarePlan: false,
      canRecordActivities: true,
      canRecordObservations: true,
      canViewHistory: true,
      canEditPatient: false,
    });

    const view = await service.getView(patient.id, professional);

    expect(view.joinCode).toBe('');
    expect(view.permissions.canEditPatient).toBe(false);
  });
});
