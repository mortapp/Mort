/// Canonical back-to-front production atmosphere contract.
///
/// [MortAtmosphericBackground] realizes this as two painter planes around an
/// optional focal brand widget, while `MortScreen` always places [realUi]
/// above the decorative stack.
enum MortAtmosphereLayer {
  sky,
  farStars,
  aurora,
  farClouds,
  backgroundMeteors,
  middleClouds,
  focalBrand,
  foregroundMeteors,
  nearClouds,
  shimmer,
  vignette,
  realUi;

  static const productionOrder = <MortAtmosphereLayer>[
    sky,
    farStars,
    aurora,
    farClouds,
    backgroundMeteors,
    middleClouds,
    focalBrand,
    foregroundMeteors,
    nearClouds,
    shimmer,
    vignette,
    realUi,
  ];
}

enum MortAtmospherePaintPhase { full, background, foreground }
