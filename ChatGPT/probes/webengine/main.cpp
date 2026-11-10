// This binary is never loaded in DMS/Quickshell.
#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QtWebEngineQuick>
#include <QDebug>

int main(int argc, char* argv[]) {
    if (argc != 2) {
        qCritical() << "Expected absolute path to Probe.qml";
        return 64;
    }
    // Call before constructing the GUI app / any OpenGL context.
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.load(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    if (engine.rootObjects().isEmpty()) return 2;
    return app.exec();
}
