import { registerDecorator, ValidationOptions, ValidationArguments } from 'class-validator';

export function IsRutChileno(validationOptions?: ValidationOptions) {
  return function (object: Object, propertyName: string) {
    registerDecorator({
      name: 'isRutChileno',
      target: object.constructor,
      propertyName: propertyName,
      options: validationOptions,
      validator: {
        validate(value: any, args: ValidationArguments) {
          if (typeof value !== 'string') return false;
          const cleanRut = value.trim().toUpperCase();
          const regex = /^([0-9]{7,8})-([0-9K])$/;
          if (!regex.test(cleanRut)) return false;

          const parts = cleanRut.split('-');
          const cuerpo = parts[0];
          const dv = parts[1];

          let suma = 0;
          let mult = 2;
          for (let i = cuerpo.length - 1; i >= 0; i--) {
            suma += parseInt(cuerpo.charAt(i), 10) * mult;
            mult = mult === 7 ? 2 : mult + 1;
          }
          const res = 11 - (suma % 11);
          let dvEsperado = '';
          if (res === 11) dvEsperado = '0';
          else if (res === 10) dvEsperado = 'K';
          else dvEsperado = res.toString();

          return dv === dvEsperado;
        },
        defaultMessage(args: ValidationArguments) {
          return 'El formato o dígito verificador del RUT chileno es inválido (ej: 12345678-K).';
        },
      },
    });
  };
}
