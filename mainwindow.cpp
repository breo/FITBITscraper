#include "mainwindow.h"
#include "ui_mainwindow.h"


MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{

    ui->setupUi(this);

    //INITIALIZATION

    //Capture current Path
    exportFolder = QDir::currentPath();
    ui->label_expoortFolder->setText(exportFolder);

    //Label with the number of selected days
    ui->label_numberSelectedDays->setText("No days selected");

    //Load users file by default (same folder as the Scraper)
    usersFilePath = QDir::currentPath() + "/PERL/users.fitbit";
    showUsersInfo();



}


MainWindow::~MainWindow()
{
    delete ui;
}



void MainWindow::on_pushButton_Scrape_clicked()
{

    //Enable OFF all of the buttons

    ui->pushButton_Scrape->setText("SCRAPING");
    QCoreApplication::processEvents();
    ui->pushButton_Scrape->setEnabled(false);
    QCoreApplication::processEvents();
    ui->pushButton_exportFolder->setEnabled(false);
    QCoreApplication::processEvents();
    QCoreApplication::processEvents();


    // FILE with the DATES
    QString filePath = QDir::currentPath() + "/PERL/dates.fitbit";
    QFile pathtofile( filePath );

     // Open for writing
     if(!pathtofile.open(QIODevice::WriteOnly| QIODevice::Text)) {
         qDebug() << "ERROR writting";
         return;
     }

     QTextStream out(&pathtofile);

     for (int i=0; i<listDates.size(); i++)
         out << listDates.at(i) << "\n";

     pathtofile.close();


     //Historical days for collecting

     QString numdays;
     numdays.setNum(ui->spinBox_numberDays->value());

     QString systemCommand = "perl /home/breo/QtSDK/FitbitScrapper/PERL/FitbitScraper_v1.pl 1 " + numdays + " " + exportFolder;
     const char* myChar = systemCommand.toStdString().c_str();

     //Execute script
     system( myChar );


     qDebug() << "FINISHED!";

     ui->pushButton_Scrape->setText("SCRAPE!");

     //Enable ON all buttons
     ui->pushButton_Scrape->setEnabled(true);
     ui->pushButton_exportFolder->setEnabled(true);
     ui->label_expoortFolder->setEnabled(true);
     ui->calendarWidget->setEnabled(true);

     QCoreApplication::processEvents();

     //Delete file with dates
}



void MainWindow::on_calendarWidget_selectionChanged()
{

    if ( ! listDates.contains(ui->calendarWidget->selectedDate().toString("yyyy-MM-dd"))) {

        //ADD ELEMENT TO THE LIST
        listDates.push_back(ui->calendarWidget->selectedDate().toString("yyyy-MM-dd"));

        // HIGHLIGHT the date on the calendar
        QTextCharFormat currentDayHighlight;
        currentDayHighlight.setBackground(Qt::cyan);
        ui->calendarWidget->setDateTextFormat(ui->calendarWidget->selectedDate(), currentDayHighlight);
    }

    else {
        //The list contains that element-> Erase Highlighting and from the list.
        listDates.removeOne(ui->calendarWidget->selectedDate().toString("yyyy-MM-dd"));

        // HIGHLIGHTS the date on the calendar
        QTextCharFormat currentDayHighlight;
        currentDayHighlight.setBackground(Qt::white);
        ui->calendarWidget->setDateTextFormat(ui->calendarWidget->selectedDate(), currentDayHighlight);
    }


    //Sort the list by date
    listDates.sort();

    //Update the number of selected days
    if ( listDates.isEmpty() )
        ui->label_numberSelectedDays->setText("No days selected");
    else
        ui->label_numberSelectedDays->setText( QString::number(listDates.size()) + " day(s) selected");

    return;
}


void MainWindow::on_pushButton_exportFolder_clicked()
{

    //Dialog for choosing a Folder
    exportFolder = QFileDialog::getExistingDirectory(this, tr("Select Directory for Exporting Data"),
                                                     "/home",
                                                     QFileDialog::ShowDirsOnly
                                                     | QFileDialog::DontResolveSymlinks);

    ui->label_expoortFolder->setText(exportFolder);
    return;

}


void MainWindow::showUsersInfo(){

    ui->listWidget_USers->clear();

    // FILE with the USERS
    QFile pathtofile( usersFilePath );

    // Open for reading
    if(!pathtofile.open(QIODevice::ReadOnly)) {
        qDebug() << "ERROR reading";
        return;
    }

    QTextStream inFile(&pathtofile);
    QString fileText;
    QStringList fields, lineParts;

    //Read all text
    fileText = inFile.readAll();

    //Crop the text throught lines
    fileText.trimmed();
    fields = fileText.split("\n");

    for (int i=0; i<fields.size()-1; i++) {

        lineParts = fields.at(i).split(",");

        ui->listWidget_USers->addItem( lineParts.at(0) + " (" + lineParts.at(3) + ")" );
    }

    pathtofile.close();

    return;

}
