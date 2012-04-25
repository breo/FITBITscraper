#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QString>
#include <QTextCharFormat>
#include <QDebug>
#include <QFileDialog>
#include <QDir>
#include <QFile>
#include <QEventLoop>
#include <QCoreApplication>

namespace Ui {
    class MainWindow;
}

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:

    explicit MainWindow(QWidget *parent = 0);
    ~MainWindow();

    QStringList listDates;
    QString exportFolder;
    int daysHistorical;
    QString usersFilePath;

    //Shows in the list the users from whom the information will be scrapped.
    void showUsersInfo();

private slots:
    void on_pushButton_Scrape_clicked();

    void on_calendarWidget_selectionChanged();

    void on_pushButton_exportFolder_clicked();

private:
    Ui::MainWindow *ui;
};

#endif // MAINWINDOW_H
