import 'package:flutter/cupertino.dart';

import '../../core/services/tramite_pdf_service.dart';

/// Descriptor de un trámite/formulario para la UI de "Procedimientos COSSMIL".
///
/// Reúne los metadatos de presentación (título, ícono, color, destinatario y
/// requisitos) junto con el [TramiteTipo] que sabe generar el PDF oficial.
class TramiteInfo {
  final TramiteTipo tipo;
  final String titulo;
  final String descripcion;
  final String destinatario;
  final IconData icon;
  final Color color;
  final List<String> requisitos;

  /// Nota breve que se muestra bajo el formulario (p. ej. campos a llenar a mano).
  final String? nota;

  const TramiteInfo({
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.destinatario,
    required this.icon,
    required this.color,
    required this.requisitos,
    this.nota,
  });

  /// Nombre de archivo sugerido para el PDF (sin extensión).
  String get fileName {
    switch (tipo) {
      case TramiteTipo.cartaDerivacion:
        return 'COSSMIL_Formulario_Derivacion_FMD';
      case TramiteTipo.devolucionServicios:
        return 'COSSMIL_Devolucion_Servicios';
      case TramiteTipo.devolucionMedicamentos:
        return 'COSSMIL_Devolucion_Medicamentos';
    }
  }
}

/// Catálogo de trámites disponibles, en orden de aparición.
const List<TramiteInfo> kTramites = [
  TramiteInfo(
    tipo: TramiteTipo.cartaDerivacion,
    titulo: 'Formulario de Derivación Médica',
    descripcion:
        'Solicita el llenado del Formulario Médico de Derivación (FMD) para '
        'iniciar tu trámite ante la Gestora Pública.',
    destinatario: 'Dirección General · HMC COSSMIL',
    icon: CupertinoIcons.arrow_turn_up_right,
    color: Color(0xFF005EB8),
    requisitos: [
      'Fotocopia de CI',
      'Fotocopia legible de certificado de nacimiento',
      'Fotocopia del carnet de seguro',
    ],
    nota:
        'La especialidad, el médico y la fecha se completan a mano sobre el '
        'documento impreso.',
  ),
  TramiteInfo(
    tipo: TramiteTipo.devolucionServicios,
    titulo: 'Devolución por Compra de Servicios',
    descripcion:
        'Reembolso por servicios médicos externos (estudios, consultas o '
        'procedimientos) realizados fuera del HMC.',
    destinatario: 'Unidad Administrativa Financiera · HMC',
    icon: CupertinoIcons.money_dollar_circle_fill,
    color: Color(0xFF059669),
    requisitos: [
      'Factura original',
      'Fotocopia simple de la factura',
      'Fotocopia legalizada de la factura (montos ≥ Bs 2.500)',
      'Resultados del estudio y/o informe médico',
      'Formulario de Compra de Servicios',
      'Carnet de identidad y de asegurado (biometrizado y vigente)',
      'Cuenta del Banco Unión (extracto, depósito o UNINET)',
    ],
    nota:
        'El monto en Bs, el N° de factura y la fecha se llenan a mano sobre el '
        'documento impreso.',
  ),
  TramiteInfo(
    tipo: TramiteTipo.devolucionMedicamentos,
    titulo: 'Devolución de Medicamentos sin Stock',
    descripcion:
        'Reembolso por medicamentos comprados por fuera al no haber stock en '
        'la Farmacia del HMC.',
    destinatario: 'Unidad Administrativa Financiera · HMC',
    icon: CupertinoIcons.bandage_fill,
    color: Color(0xFFD97706),
    requisitos: [
      'Factura original sellada por Serv. Médicos',
      'Receta con sello SIN STOCK y visto de Dirección Médica',
      'Fotocopia de la factura',
      'Fotocopia de carnet de identidad (vigente)',
      'Carnet de asegurado (biometrizado y vigente)',
      'Cuenta del Banco Unión (extracto, depósito o UNINET)',
    ],
    nota:
        'El monto en Bs, el N° de factura y la fecha se llenan a mano sobre el '
        'documento impreso.',
  ),
];
