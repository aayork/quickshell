// LD_PRELOAD shim for bin/vlc-themed.
//
// 1. Registers the themed icon resources (VLC_THEMED_RCC) before VLC's Qt
//    plugin loads. Qt resolves a resource path from the first registered
//    tree that has it, so these replace VLC's built-in :/toolbar/... icons
//    without touching VLC.
// 2. Joins VLC's toolbar button groups into one segmented control. VLC puts
//    each run of adjacent buttons in its own QHBoxLayout, which a stylesheet
//    cannot see, so every QToolButton in such a run gets a "segment"
//    property (first/middle/last/only) and the run's spacing is set to 0.
//    themed/qt5ct-vlc.qss.tpl squares the inner corners and keeps a single
//    divider between neighbours.
//
// 3. Stops the doubled "playlist is empty" message (see Segmenter).
// 4. Wraps the style so Qt's standard icons that VLC asks for (the playlist's
//    view-mode button) come from the themed set too.
//
// The variables are cleared so programs VLC starts do not inherit the shim.

#include <QtCore/QFile>
#include <QtCore/QResource>
#include <QtWidgets/QAbstractScrollArea>
#include <QtWidgets/QApplication>
#include <QtWidgets/QLayout>
#include <QtWidgets/QStyle>
#include <QtWidgets/QStyleFactory>
#include <QtWidgets/QProxyStyle>
#include <QtWidgets/QToolButton>
#include <QtCore/QTimer>
#include <cstdlib>

__attribute__((constructor)) static void registerThemedIcons() {
  const char *rcc = getenv("VLC_THEMED_RCC");
  if (rcc && *rcc) QResource::registerResource(QString::fromLocal8Bit(rcc));
  unsetenv("VLC_THEMED_RCC");
  unsetenv("LD_PRELOAD");
}

// The layout directly holding `w`, searched from its parent's top layout.
static QLayout *holder(QLayout *layout, QWidget *w) {
  if (!layout) return nullptr;
  for (int i = 0; i < layout->count(); ++i) {
    QLayoutItem *item = layout->itemAt(i);
    if (item->widget() == w) return layout;
    if (QLayout *inner = holder(item->layout(), w)) return inner;
  }
  return nullptr;
}

static void restyle(QWidget *w, const char *segment) {
  if (w->property("segment").toString() == QLatin1String(segment)) return;
  w->setProperty("segment", segment);
  w->style()->unpolish(w);
  w->style()->polish(w);
  w->update();
}

// Mark every visible button in the run that holds `button`.
static void segment(QToolButton *button) {
  QWidget *parent = button->parentWidget();
  QLayout *layout = parent ? holder(parent->layout(), button) : nullptr;
  auto *row = qobject_cast<QHBoxLayout *>(layout);
  if (!row || row == parent->layout()) return;  // not one of VLC's groups

  QList<QToolButton *> run;
  for (int i = 0; i < row->count(); ++i) {
    auto *b = qobject_cast<QToolButton *>(row->itemAt(i)->widget());
    if (!b) return;  // something other than buttons: leave it alone
    if (b->isVisibleTo(parent)) run << b;
  }
  row->setSpacing(0);
  for (int i = 0; i < run.size(); ++i)
    restyle(run[i], run.size() == 1 ? "only" : i == 0 ? "first" : i == run.size() - 1 ? "last" : "middle");
}

class Segmenter : public QObject {
 public:
  bool eventFilter(QObject *obj, QEvent *event) override {
    // VLC's playlist views (children of StandardPLPanel) draw the "playlist
    // is empty" message from a filter on both the view and its viewport.
    // Once the stylesheet gives the view a background, the view itself
    // repaints too and VLC draws a second copy, offset by the view's
    // position. The viewport covers the whole view (no border), so the
    // view's own paint carries nothing: drop it before VLC's filter sees it.
    if (event->type() == QEvent::Paint) {
      auto *area = qobject_cast<QAbstractScrollArea *>(obj);
      if (area && area->parent() && area->parent()->inherits("StandardPLPanel")) return true;
    }
    if (event->type() == QEvent::Show || event->type() == QEvent::Hide) {
      if (auto *b = qobject_cast<QToolButton *>(obj)) segment(b);
    }
    return false;
  }
};

class ThemedStyle : public QProxyStyle {
 public:
  using QProxyStyle::QProxyStyle;
  QIcon standardIcon(StandardPixmap sp, const QStyleOption *opt, const QWidget *w) const override {
    const char *path = nullptr;
    switch (sp) {
      case SP_FileDialogDetailedView: path = ":/toolbar/playlist.svg"; break;
      case SP_FileDialogListView: path = ":/toolbar/playlist.svg"; break;
      case SP_FileDialogContentsView: path = ":/sidebar/pictures.svg"; break;
      default: break;
    }
    if (path && QFile::exists(path)) return QIcon(path);
    return QProxyStyle::standardIcon(sp, opt, w);
  }
};

static void installSegmenter() {
  if (!qobject_cast<QApplication *>(QCoreApplication::instance())) return;
  qApp->installEventFilter(new Segmenter);
  // Wrap qt5ct's style (Fusion underneath). By the time this runs qt5ct's
  // stylesheet already wraps the app style, and that wrapper has no name,
  // so ask for the style by name. Qt re-wraps it for the stylesheet.
  QTimer::singleShot(0, [] {
    QStyle *base = QStyleFactory::create("qt5ct-style");
    if (!base) base = QStyleFactory::create("Fusion");
    if (base) qApp->setStyle(new ThemedStyle(base));
  });
}
Q_COREAPP_STARTUP_FUNCTION(installSegmenter)
