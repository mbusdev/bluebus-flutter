import 'dart:math';

class Vec3 {
  final double x, y, z;

  Vec3(this.x, this.y, this.z);

  Vec3 scale(double k) {
    return Vec3(x * k, y * k, z * k);
  }

  double norm() {
    return sqrt(this * this);
  }

  Vec3 normalize() {
    return scale(1.0 / norm());
  }

  Vec3 operator+(Vec3 v) {
    return Vec3(x + v.x, y + v.y, z + v.z);
  }

  Vec3 operator-(Vec3 v) {
    return Vec3(x - v.x, y - v.y, z - v.z);
  }

  double operator*(Vec3 v) {
    return x * v.x + y * v.y + z * v.z;
  }

  Vec3 cross(Vec3 v) {
    return Vec3(
      y * v.z - z * v.y,
      x * v.z - z * v.x,
      x * v.y - y * v.x
    );
  }

  @override
  String toString() {
    return "<$x, $y, $z>";
  }
}

