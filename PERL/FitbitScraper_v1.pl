#!/usr/bin/perl -w

## Cambiar uso de folders: relativos no absolutos

use lib "$ENV{HOME}/QtSDK/FitbitScrapper/PERL/";
use lib "$ENV{HOME}/QtSDK/FitbitScrapper/PERL/conf";
use lib "$ENV{HOME}/QtSDK/FitbitScrapper/PERL/log";

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTTP::Request::Common qw(GET);
use HTML::Strip;
use DateTime;
use Class::Struct;
use HTTP::Cookies;
use URI::Escape;
use HTTP::Headers;
use File::Slurp qw(write_file);
use FitbitClient;
use POSIX;
use Text::CSV;

#Users configuration 
my $usersFileString = 'users.fitbit';	#name of the users file
my $daysForCollecting;					#number of days for collecting data (steps, sleep, day activity) Comes from arguments
my $daysAccumulated;					#number of total days for the accumulated data (for the historical graph) Comes from arguments

#Arrays with users' information
my @userNames;			
my @passwords;
my @user_ids;
my @outputLabels;

#Dates
my @datesExtract;

#Variables
my $username;
my $password;
my $user_id;
my $labelName;	
my $sid;
my $uid;
my $u;
my $error=1;	
my $ExportFolder;		
		
		
		
my $eoeo = strftime( "%F", localtime( time ));

my $eoeoeo = strftime( "%F", localtime( time - 86400 ) );


print "formato del dia: " . $eoeo . "/n/n";
print "formato del dia 2: " . $eoeoeo . "/n/n";
		
		
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
##### ##### ##### ##### #####           SCRIPT        ##### ##### ##### ##### ##### #####
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####

## CAPTURE ARGUMENTS		
my $numArgs = $#ARGV + 1; 		
if ($numArgs!= 3) {	
	print "ERROR in the number of arguments\n";
	exit;
} 

$daysForCollecting= $ARGV[0];
$daysAccumulated= $ARGV[1];
$ExportFolder= $ARGV[2];
		

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####

print "------------------------ COLLECTING DATA FROM FITBIT ----------------------\n";

print "\n**** Number of days for collecting: " . $daysForCollecting . "\n";
print "**** Number of days for the historical data: " . $daysAccumulated . "\n\n";


## Reads the Users file
ReadUsersFile();
			
##Reads Dates File
ReadDatesFile();
			
## Loop for collecting data from each user
for (my $indexUsers = 0 ; $indexUsers < scalar(@userNames) ; $indexUsers++) {
	
	#print " Deleting cookies file \n  ";
	unlink("lwp_cookies.jar");
	
	$username = $userNames[$indexUsers];
	$password = $passwords[$indexUsers];
	$user_id = $user_ids[$indexUsers];
	$labelName = $outputLabels[$indexUsers];
		
	print "\n\n-----------------------------------------------------------------\n";	
	print "\nCollecting data from the user labeled as: " . $labelName .  "\n";

			
	while ($error) {	
		## Retrieves information fron the cookies ########################
		$error = DownloadHTMLS($username,$password,$sid,$uid,$u);	
		if ($error) 
		{
			print "Error while downloading, retrying in 1 minute\n\n"; 
			sleep (60);
		}
	}
	
	$error=1;	

	### Creates the configuration file ###################################
	CreateConfFile($user_id, $sid, $uid, $u);

	#### Extracts the data to the output files ###########################
	ExtractData($labelName, $ExportFolder);
}

print "\n\n\n";
exit;


##################################################################################################################################
################################ SUB ROUTINES ####################################################################################
##################################################################################################################################

#READS the Users file for download its information
sub ReadUsersFile {
	
	my $usersFile = '/home/breo/QtSDK/FitbitScrapper/PERL/users.fitbit';
	
	##my $usersFile = $usersFileString;
    my $csv = Text::CSV->new();

    open (CSV, "<", $usersFile) or die $!;

    while (<CSV>) {
        if ($csv->parse($_)) {
            my @columns = $csv->fields();
            
            push (@userNames, $columns[0]);
            push (@passwords, $columns[1]);
            push (@user_ids, $columns[2]);
            push (@outputLabels, $columns[3]);
            
        } else {
            my $err = $csv->error_input;
            print "Failed to parse line: $err";
        }
    }
    close CSV;
          
	return 0;
}


#READS the Dates File
sub ReadDatesFile {
	
	my $datesFilePath = '/home/breo/QtSDK/FitbitScrapper/PERL/dates.fitbit';
	
    my $datesFile = Text::CSV->new();

    open (DATESFILE, "<", $datesFilePath) or die $!;

    while (<DATESFILE>) {
        if ($datesFile->parse($_)) {
            my @columns = $datesFile->fields();
            
            push (@datesExtract, $columns[0]);
            
        } else {
            my $err = $datesFile->error_input;
            print "Failed to parse line: $err";
        }
    }
    close DATESFILE;
          
	return 0;
}

#DOWNLOADS EVENT LIST AND EVENT STATUS FROM THE WEBSITE FOR THE GIVEN USERNAME AND PASSWORD
#USAGE : $error = DownloadHTMLS($username,$password,$sid,$uid,$u);
#Returns 0 for OK, 1 for ERROR.
sub DownloadHTMLS {

	my $cookie_jar = HTTP::Cookies->new(
	  file => "lwp_cookies.dat",
	  autosave => 1,
	);

	my $useragent = LWP::UserAgent->new;
	$useragent->cookie_jar($cookie_jar);

	my $url = 'https://m.fitbit.com/login';
	my $request = GET $url;
	my $response;
	my $username = $_[0];
	my $password = $_[1];
	my $uid;
	my $sid;
	my $u;
	
	############################################################################################
	# FIRST GET: From the answer (Response Header), extract the JSESIONID
	
	print "\nGEETING THE INFORMATION FROM THE COOKIES: \n";
	#print "\n GET http://www.fitbit.com ... \n";
	$response = $useragent->request($request);
	
	#print $response->status_line() . "\n";
	
	if (!$response->is_error) 
	{
		my $endindex   = index $response->header( "Set-Cookie" ),'.fitbit1';
		$sid  = substr $response->header( "Set-Cookie" ), 11 , $endindex - 11;
		#print "Obtained JSESSIONID:\t" . $sid. "\n";
		$cookie_jar->extract_cookies( $response );
	} 
	else 
	{
		return 1;
	}
	
	# Obtain sourcepage and fp from the downloaded html page.
	my $sourcepage;
	my $fp;

	my $startindex 	= 47 + index $response->content,'<input type="hidden" name="_sourcePage" value="',0;
	my $endindex   	= index $response->content,'" />', $startindex;
	$sourcepage  	= substr $response->content, $startindex, $endindex - $startindex;
	
	$startindex    	= 40 + index $response->content,'<input type="hidden" name="__fp" value="',0;
	$endindex      	= index $response->content,'" />', $startindex;
	$fp   			= substr $response->content, $startindex, $endindex - $startindex;
	
	############################################################################################
	#POST: Posting the credentials, login and password
	#
	# Obtaining the uid and the u cookies necessary for accesing to the data
	#
	
	#print "\n\nPOSTing username and password to " . $url . "\n\n";
	
	$request = POST $url, [email => ($username), password => ($password), login => ("Log In"), includeWorkflow => (''), redirect => (''), _sourcePage => ($sourcepage), __fp => ($fp) ];
	$request ->header( Host => 'www.fitbit.com', 
				     User_Agent => 'User-Agent=Mozilla/5.0 (X11; Linux x86_64; rv:7.0.1) Gecko/20100101 Firefox/7.0.1',
				     Accept => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
				     Accept_Language => 'en-us,en;q=0.5',
				     Accept_Encoding => 'gzip, deflate',
				     Accept_Charset => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
				     Connection => 'keep-alive',
				     Referer => 'https://www.fitbit.com/login',
				     content_type => 'application/x-www-form-urlencoded');
		
	$cookie_jar->add_cookie_header( $request );
	$response = $useragent->request($request);
	
	# Extracting the Cookies: u and uid from the response
	$startindex 	= 2 + index $response->header('Set-Cookie'),'u=.',0;
	$endindex   	= index $response->header('Set-Cookie'),';', $startindex;
	$u  	= substr $response->header('Set-Cookie'), $startindex, $endindex - $startindex;
	
	$startindex 	= 4 + index $response->header('Set-Cookie'),'uid=',0;
	$endindex   	= index $response->header('Set-Cookie'),';', $startindex;
	$uid  	= substr $response->header('Set-Cookie'), $startindex, $endindex - $startindex;
	
	#output to a fil
	#use File::Slurp qw(write_file);
	#write_file('response.html', $response->as_string);
	
	print "** SID: " . $sid . "\n";
	print "** uid: " . $uid . "\n";
	print "** u: " . $u . "\n";

	$_[2] = $sid;
	$_[3] = $uid;
	$_[4] = $u;

	return 0;
}

#CREATES THE CONFIGURATION FILE
#USAGE: CreateConfFile($user_id, $sid, $uid, $u);
sub CreateConfFile {
	
	my $user_id = $_[0];
	my $sid = $_[1];
	my $uid = $_[2];
	my $u = $_[3];
	
	### Creates the configuration file from the Cookies extraction ##########################################
	# Structure:
	#	{
    # 		# Available from fitbit profile URL
    #		'user_id' => '22DTHG',
    #		# Populated by cookie
    #		'sid' => '7A2B844200E0EF7594A1ED4E57571AE3',              
    #		'uid' => '429236',
    #		'u' => '.2|429236|4600F90D-9D2B-A295-0E57-793774EF8CA1|1328624961564|31536000'
	#	};
	
	my $dir = "$ENV{HOME}/QtSDK/FitbitScrapper/PERL/conf/";

	unless(-d $dir){
		mkdir $dir or die;
	};
	
	
	##system("mkdir conf") if !-e "configuration";
	
	open( CONF_FILE, ">conf/fitbit.conf" ) or die "Can't open Configuration file!";
	
	print CONF_FILE "{ \n";
	print CONF_FILE "# Available from fitbit profile URL\n";
	print CONF_FILE "'user_id' => " . "'" . $user_id . "',\n";
	print CONF_FILE "# Populated by cookie \n";
	print CONF_FILE "'sid' =>" . "'" . $sid . "',\n";
	print CONF_FILE "'uid' =>" . "'" . $uid . "',\n";
	print CONF_FILE "'u' =>" . "'" . $u . "'\n";
	print CONF_FILE "}; \n";
	
	close(CONF_FILE);
	
	print ("\nCreated configuration file\n");
	
}

#Extracts the data after the configuration file is created
sub ExtractData {
	
	#input parameters: label
	my $label = $_[0];
	my $fb = new FitbitClient( config => 'conf/fitbit.conf' );
	
	##cambiar dia de acceso@@@@@@@@@@@@@@@@@@@
	my $day = 86400;    # 1 day
	my $total_days = $daysForCollecting;
	my $total_days_accumulate = $daysAccumulated;
	

	## OUTPUT FOLDER
	##cambiar folder salida @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	## vendra por parametros (de la gui)
	my $exportF = $_[1];
	
	unless(-d $exportF){
		mkdir $exportF or die;
	};
	
	
	# Weekly CSV header
	for ( my $i = 0 ; $i < scalar(@datesExtract) ; $i++ ) {
	
		my $targetDay = $datesExtract[$i];
	
		##Create a folder for each day with the date as name
		my $dayFolder = $exportF . "/" .  $targetDay ;		
		unless(-d $dayFolder){
			mkdir $dayFolder or die;
		};
	
	
		
		
		print "\nGetting data from $targetDay ...\n";
		
		#OPENING FILES
		open( TOTALS_CSV, ">" . $dayFolder . "/" . "[" . $label . "]" . $targetDay . "_DayActivity.csv" ) or die "Can't open CSV file!";
		open( STEPS_CSV, ">" . $dayFolder . "/" . "[" . $label . "]" . $targetDay . "_StepsTracker.csv" ) or die "Can't open CSV file!";
		open( SLEEPING_CSV, ">" . $dayFolder . "/" . "[" . $label . "]" . $targetDay . "_SleepingTracker.csv" ) or die "Can't open CSV file!";
		open ( ACCUMULATED_CSV, ">" . $dayFolder . "/"  . "[" . $label . "]" . $targetDay . "_Accumulated.csv" ) or die "Can't open CSV file!";	
	
		
		### TOTALS TRACKER ########################
		print TOTALS_CSV
		qq{DATE,BURNED,CONSUMED,SCORE,STEPS,DISTANCE,ACTIVE_VERY,ACTIVE_FAIR,ACTIVE_LIGHT,SLEEP_TIME,AWOKEN};
		print TOTALS_CSV "\n";
	    print TOTALS_CSV $targetDay . ",";
	    print TOTALS_CSV $fb->total_calories($targetDay)->{burned} . ",";
	    print TOTALS_CSV $fb->total_calories($targetDay)->{consumed} . ",";
	    print TOTALS_CSV $fb->total_active_score($targetDay) . ",";
	    print TOTALS_CSV $fb->total_steps($targetDay) . ",";
	    print TOTALS_CSV $fb->total_distance($targetDay) . ",";
		
	    my $ah = $fb->total_active_hours($targetDay);
	    print TOTALS_CSV $ah->{very} . ",";
	    print TOTALS_CSV $ah->{fairly} . ",";
	    print TOTALS_CSV $ah->{lightly} . ",";
		
	    my $st = $fb->total_sleep_time($targetDay);
	    print TOTALS_CSV $st->{hours_asleep} . ",";
	    print TOTALS_CSV $st->{wakes} . "\n";
	    
	    printf ".... Activity tracker\n";
	    
	    
	    ### SLEEP TRACKER ########################
	    my @log = $fb->get_sleep_log($targetDay);   
	    foreach (@log) {
	    print SLEEPING_CSV "time = " . $_->{time} . ": status = " . $_->{value} . "\n";
	    }
		
		printf "........ Sleeping tracker\n";
	
		
		###### STEPS TRACKER ##################
	    my @logStep = $fb->get_step_log($targetDay);   
	    foreach (@logStep) {
	    print STEPS_CSV "time = " . $_->{time} . ": steps = " . $_->{value} . "\n";
	    }
		
		printf "............ Steps tracker\n";
		
		
		close(TOTALS_CSV);
		close(SLEEPING_CSV);
		close(STEPS_CSV);
		
		
		#New scraping
		my $day_accumulate = 86400;
		my $targetDay_accumulate = $targetDay;
	    
	    
		###### ACCUMULATED TRACKER ##################
		
		print ACCUMULATED_CSV qq{DATE,BURNED,CONSUMED,SCORE,STEPS,DISTANCE,ACTIVE_VERY,ACTIVE_FAIR,ACTIVE_LIGHT,SLEEP_TIME,AWOKEN};
		print ACCUMULATED_CSV "\n";
	
		for ( my $i2 = 0 ; $i2 < $total_days_accumulate ; $i2++ ) {
		
			my $targetDay_accumulated = strftime( "%F", localtime( time - $day_accumulate ) );
			#print "Getting Accumulated data for $targetDay_accumulated ...\n";
	   	
			print ACCUMULATED_CSV $targetDay_accumulated . ",";
			print ACCUMULATED_CSV $fb->total_calories($targetDay_accumulated)->{burned} . ",";
			print ACCUMULATED_CSV $fb->total_calories($targetDay_accumulated)->{consumed} . ",";
			print ACCUMULATED_CSV $fb->total_active_score($targetDay_accumulated) . ",";
			print ACCUMULATED_CSV $fb->total_steps($targetDay_accumulated) . ",";
			print ACCUMULATED_CSV $fb->total_distance($targetDay_accumulated) . ",";
		
			my $ah = $fb->total_active_hours($targetDay_accumulated);
			print ACCUMULATED_CSV $ah->{very} . ",";
			print ACCUMULATED_CSV $ah->{fairly} . ",";
			print ACCUMULATED_CSV $ah->{lightly} . ",";
		
			my $st = $fb->total_sleep_time($targetDay_accumulated);
			print ACCUMULATED_CSV $st->{hours_asleep} . ",";
			print ACCUMULATED_CSV $st->{wakes} . "\n";
		
			$day_accumulate += 86400;
		}
		
		close(ACCUMULATED_CSV);
		
		printf "................ Collected Historical Activity\n";
		
	    $day += 86400;
	}   
}#function
