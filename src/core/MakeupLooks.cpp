#include "MakeupLooks.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtGlobal>

// Static-library resources are only pulled into the link when something references them.
static void initMakeupLookResources()
{
    Q_INIT_RESOURCE(drift_makeup_looks);
}

namespace drift {

const MakeupLook *MakeupLookCatalog::find(const QString &id) const
{
    for (const MakeupLook &look : looks) {
        if (look.id == id)
            return &look;
    }
    return nullptr;
}

MakeupLookCatalog parseMakeupLooks(const QByteArray &json, QString *error)
{
    MakeupLookCatalog catalog;
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &parseError);
    if (!doc.isObject()) {
        if (error)
            *error = parseError.errorString();
        return catalog;
    }
    const QJsonObject root = doc.object();

    const QJsonObject amounts = root.value(QStringLiteral("amountKeys")).toObject();
    for (auto it = amounts.constBegin(); it != amounts.constEnd(); ++it) {
        QStringList keys;
        for (const QJsonValue &key : it.value().toArray())
            keys.append(key.toString());
        catalog.amountKeys.insert(it.key(), keys);
    }

    for (const QJsonValue &value : root.value(QStringLiteral("looks")).toArray()) {
        const QJsonObject object = value.toObject();
        MakeupLook look;
        look.id = object.value(QStringLiteral("id")).toString();
        look.label = object.value(QStringLiteral("label")).toString(look.id);
        for (const QJsonValue &colour : object.value(QStringLiteral("swatch")).toArray())
            look.swatch.append(colour.toString());
        for (const QJsonValue &layerValue : object.value(QStringLiteral("layers")).toArray()) {
            const QJsonObject layerObject = layerValue.toObject();
            MakeupLookLayer layer;
            layer.effectId = layerObject.value(QStringLiteral("effectId")).toString();
            const QJsonObject params = layerObject.value(QStringLiteral("params")).toObject();
            for (auto it = params.constBegin(); it != params.constEnd(); ++it)
                layer.params.insert(it.key(), it.value().toVariant());
            // A layer for an effect the looks do not know how to scale would ignore the slider.
            if (!layer.effectId.isEmpty() && catalog.isMakeupEffect(layer.effectId))
                look.layers.append(layer);
        }
        if (!look.id.isEmpty() && !look.layers.isEmpty())
            catalog.looks.append(look);
    }
    return catalog;
}

const MakeupLookCatalog &makeupLookCatalog()
{
    static const MakeupLookCatalog catalog = [] {
        initMakeupLookResources();
        QFile file(QStringLiteral(":/makeup-looks/looks.json"));
        if (!file.open(QIODevice::ReadOnly))
            return MakeupLookCatalog{};
        return parseMakeupLooks(file.readAll());
    }();
    return catalog;
}

QMap<QString, QVariant> scaledMakeupParams(const MakeupLookCatalog &catalog,
                                           const MakeupLookLayer &layer, double intensity)
{
    const double t = qBound(0.0, intensity, 1.0);
    const QStringList amounts = catalog.amountKeys.value(layer.effectId);
    QMap<QString, QVariant> params = layer.params;
    for (auto it = params.begin(); it != params.end(); ++it) {
        if (amounts.contains(it.key()))
            it.value() = it.value().toDouble() * t;
    }
    return params;
}

} // namespace drift
