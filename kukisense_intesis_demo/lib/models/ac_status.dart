class AcStatus {
  final bool power;
  final String mode;
  final double setpoint;
  final String fan;
  final bool online;
  final double? roomTemp;

  AcStatus({
    this.power = false,
    this.mode = 'COOL',
    this.setpoint = 24.0,
    this.fan = 'AUTO',
    this.online = false,
    this.roomTemp,
  });

  factory AcStatus.fromJson(Map<String, dynamic> json) {
    return AcStatus(
      power: json['ac_power'] == true || json['ac_power'] == 'true',
      mode: json['ac_mode'] ?? 'COOL',
      setpoint: (json['ac_setpoint'] ?? 24.0).toDouble(),
      fan: json['ac_fan'] ?? 'AUTO',
      online: json['ac_online'] == true || json['ac_online'] == 'true',
      roomTemp: json['ac_room_temp']?.toDouble(),
    );
  }
}
