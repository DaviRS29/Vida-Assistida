import { TransformFnParams } from 'class-transformer';

export const trimString = ({ value }: TransformFnParams): string =>
  typeof value === 'string' ? value.trim() : '';

export const normalizeEmail = ({ value }: TransformFnParams): string =>
  typeof value === 'string' ? value.trim().toLowerCase() : '';

export const normalizeCode = ({ value }: TransformFnParams): string =>
  typeof value === 'string' ? value.trim().toUpperCase() : '';

export const onlyDigitsTransform = ({
  value,
}: TransformFnParams): string | undefined =>
  typeof value === 'string' && value.trim() !== ''
    ? value.replace(/\D/g, '')
    : undefined;
