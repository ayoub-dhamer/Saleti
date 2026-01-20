import 'dart:math';

double calculateQiblaDirection(double lat, double lon) {
  const kaabaLat = 21.4225;
  const kaabaLon = 39.8262;

  final phiK = kaabaLat * pi / 180.0;
  final lambdaK = kaabaLon * pi / 180.0;
  final phi = lat * pi / 180.0;
  final lambda = lon * pi / 180.0;

  final y = sin(lambdaK - lambda);
  final x = cos(phi) * tan(phiK) - sin(phi) * cos(lambdaK - lambda);

  final bearing = atan2(y, x) * 180 / pi;
  return (bearing + 360) % 360;
}
