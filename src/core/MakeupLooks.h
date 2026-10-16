#pragma once

#include <QByteArray>
#include <QList>
#include <QMap>
#include <QString>
#include <QStringList>
#include <QVariant>

namespace drift {

// One effect of a makeup look: a beauty effect from the catalog and the values the look gives it.
struct MakeupLookLayer
{
    QString effectId;
    QMap<QString, QVariant> params;
};

// A one-tap makeup look (Natural, Glam, …): a set of the beauty effects that already exist, with
// their values at full intensity.
struct MakeupLook
{
    QString id;
    QString label;          // English fallback; the app translates by id
    QStringList swatch;     // colours shown on the look's card
    QList<MakeupLookLayer> layers;
};

struct MakeupLookCatalog
{
    QList<MakeupLook> looks;
    // Per effect, the params that are an amount and follow the intensity slider. Everything else
    // (colours, shapes, feathering, thresholds) is part of the look and stays put.
    QMap<QString, QStringList> amountKeys;

    const MakeupLook *find(const QString &id) const;
    bool isMakeupEffect(const QString &effectId) const { return amountKeys.contains(effectId); }
};

// Param keys a look writes next to the effect's own params, so a later look (or the inspector)
// can tell which effects it owns and at what intensity. No shader declares a uniform by these
// names, so they never reach the GPU.
inline constexpr char kMakeupLookParam[] = "makeupLook";
inline constexpr char kMakeupIntensityParam[] = "makeupIntensity";

MakeupLookCatalog parseMakeupLooks(const QByteArray &json, QString *error = nullptr);

// The bundled looks (:/makeup-looks/looks.json), parsed once.
const MakeupLookCatalog &makeupLookCatalog();

// The layer's params at `intensity` (clamped to 0..1): amount params scaled from zero, the rest
// as the look sets them.
QMap<QString, QVariant> scaledMakeupParams(const MakeupLookCatalog &catalog,
                                           const MakeupLookLayer &layer, double intensity);

} // namespace drift
