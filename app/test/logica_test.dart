import 'package:flutter_test/flutter_test.dart';
import 'package:zona_repostera/models/models.dart';
import 'package:zona_repostera/services/pro.dart';
import 'package:zona_repostera/theme.dart';

void main() {
  group('Derivados de inscripción', () {
    Inscripcion insc(double precio, double pagado, {String estatus = 'activa'}) =>
        Inscripcion.withPagos({
          'id': 1,
          'alumna_id': 1,
          'curso_programado_id': 1,
          'precio_acordado': precio,
          'pagado': pagado,
          'estatus': estatus,
        });

    test('saldo = precio - pagos, nunca capturado', () {
      expect(insc(700, 300).saldo, 400);
      expect(insc(700, 700).saldo, 0);
    });

    test('estado de pago calculado', () {
      expect(insc(700, 0).estadoPago, 'Apartado');
      expect(insc(700, 300).estadoPago, 'Parcial');
      expect(insc(700, 700).estadoPago, 'Pagado');
      expect(insc(700, 300, estatus: 'cancelada').estadoPago, 'Cancelada');
    });
  });

  group('Rentabilidad', () {
    test('utilidad y margen', () {
      const r = RentabilidadCurso(
          ventas: 7000, costoTotal: 2800, inscritas: 10, cupoMaximo: 10);
      expect(r.utilidad, 4200);
      expect(r.margen, 60);
      expect(r.costoPorAlumna, 280);
      expect(r.ticket, 700);
      expect(r.ocupacion, 100);
    });

    test('sin ventas no truena', () {
      const r = RentabilidadCurso(
          ventas: 0, costoTotal: 500, inscritas: 0, cupoMaximo: 10);
      expect(r.margen, 0);
      expect(r.costoPorAlumna, 0);
    });
  });

  group('Semáforo de rentabilidad', () {
    test('clasificación por margen', () {
      expect(semaforoMargen(65).$1, 'MUY RENTABLE');
      expect(semaforoMargen(45).$1, 'RENTABLE');
      expect(semaforoMargen(30).$1, 'NORMAL');
      expect(semaforoMargen(15).$1, 'BAJO');
      expect(semaforoMargen(5).$1, 'NO RENTABLE');
    });
  });

  group('Utilidad bruta vs operativa', () {
    test('los costos fijos separan las dos utilidades', () {
      const r = ResumenMes(
        ventas: 50000,
        cobrado: 45000,
        pendiente: 5000,
        costosDirectos: 18000,
        costosFijos: 12000,
        cursos: 8,
        inscripciones: 60,
        alumnasNuevas: 15,
        alumnasRecurrentes: 30,
        ocupacionPromedio: 82,
      );
      expect(r.utilidadBruta, 32000);
      expect(r.utilidadOperativa, 20000);
      expect(r.margen, 64);
      expect(r.ticketPromedio.round(), 833);
    });
  });

  group('Clasificación de alumnas', () {
    Alumna alumna(int cursos, double gastado, {String? ultima}) =>
        Alumna.fromMap({
          'id': 1,
          'nombre': 'Mariana',
          'cursos_tomados': cursos,
          'total_gastado': gastado,
          'ultima_compra': ultima ?? DateTime.now().toIso8601String(),
        });

    test('VIP por frecuencia o gasto', () {
      expect(alumna(4, 100).clasificacion, 'VIP');
      expect(alumna(1, 4500).clasificacion, 'VIP');
    });

    test('nueva, recurrente, inactiva', () {
      expect(alumna(1, 700).clasificacion, 'NUEVA');
      expect(alumna(2, 1500).clasificacion, 'RECURRENTE');
      expect(
          alumna(1, 700,
                  ultima: DateTime.now()
                      .subtract(const Duration(days: 90))
                      .toIso8601String())
              .clasificacion,
          'INACTIVA');
    });
  });

  group('Códigos PRO', () {
    test('checksum válido e inválido', () {
      // AAAA: (65*4)*7 % 10000 = 1820
      expect(ProService.codigoValido('ZR-AAAA-1820'), isTrue);
      expect(ProService.codigoValido('zr-aaaa-1820'), isTrue);
      expect(ProService.codigoValido('ZR-AAAA-0000'), isFalse);
      expect(ProService.codigoValido('cualquier cosa'), isFalse);
    });
  });
}
