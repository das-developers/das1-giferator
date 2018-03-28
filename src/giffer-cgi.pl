#!/opt/csw/bin/perl
#
##

use CGI;

$query = new CGI;
$logfile = 'das.'.$query->remote_addr().'.log';

open(LOG, ">/home/Web/tmp/$logfile") or
  &PrintErrorExit ("Cannot open log file $logfile");
$referer = $query->referer();
chmod(0666, "/home/Web/tmp/$logfile");
$saveSTDERR = *STDERR;
*STDERR = *LOG;

if (0 && $query->remote_host =~ /\./) {
  &PrintHeader;
  print <<EOH;
<H3><img src="/gifs/construc.gif" alt=""> Repairs in Progress . . .</H3>
<hr>
<p>We're sorry, but external access is restricted until some bugs can be
squashed.</p>
<p>Under none-too-uncommon circumstances the server is sent into
an infinite loop if the client refuses to accept all of the data (plot).</p>
<p>If you <b>know how to avoid this bug</b> and <i>really</i> need to make
a plot from a remote site, and know the <a href="/datasetroot">name of
the dataset</a> that you want to plot, you can try
<a href="/~ljg/das-old.html">this form</a>.</p>

EOH
  &PrintTrailer;
  exit(0);
}

# Setup IDL environment

$ENV{'RSI_DIR'} = '/local/rsi';
$idl_dir  = '/local/rsi/idl_5.3';
$ENV{'IDL_DIR'} = $idl_dir;
$ENV{'PATH'} = '/usr/bin:/bin:/opt/csw/bin:/local/rsi/idl_5.3/bin';
$ENV{'LM_LICENSE_FILE'} = '/local/itt/license/license.dat';
#$ENV{'IDL_PATH'}  ="\+$idl_dir/lib";
#$ENV{'IDL_STARTUP'} = '' if $ENV{'IDL_STARTUP'};
#$ENV{'LD_LIBRARY_PATH'} = "/home/ljg/lib";
$ENV{'LD_LIBRARY_PATH'} = "/usr/lib:/opt/SUNWspro/lib:/usr/openwin/lib:/usr/dt/lib:/opt/csw/lib:/local/lib:/opt/local/lib";
#$ENV{'LD_LIBRARY_PATH'} = "/usr/lib";

print LOG "CGI shell environment:\n", `env`, "\nIDL transactions:\n";

# Open pipe to IDL process

if (!open(PROG, "| /local/bin/idl 2>> /home/Web/tmp/$logfile")) {
  &PrintHeader;
  print "<H1>ERROR: Could not open pipe to IDL process</H1>\n";
  &PrintTrailer;
  exit(0);
}

# send IDL commands

print PROG <<EOH;
ON_ERROR, 1
CD, '/home/Web/das/idl/'
RESTORE, 'gifer.idl'
;.RUN xbin.pro
;.RUN tnaxes.pro
;.RUN dasbin.pro
;.RUN sinterp.pro
.RUN giferator.pro
referer = "$referer"
logfile = "$logfile"
EOH

# check to see whether we were in demo mode due to all of the
# licenses being checked out

$line=`head -2 /home/Web/tmp/$logfile | tail -1`;
if ($line =~ ".+LICENSE MANAGER.+") {
  &PrintErrorExit("All IDL licenses checked out");
}

if ($0 =~ /das-gray.cgi/ || $query->param('gray scale')) {
  print PROG<<EOH;
  gray=interpolate([255,0],(findgen(200)/199.))
  display.color.r=gray
  display.color.g=gray
  display.color.b=gray
EOH
  $query->delete('gray scale');
} elsif ($query->param('yarg scale')) {
  print PROG<<EOH;
  gray=interpolate([0,255],(findgen(200)/199.))
  display.color.r=gray
  display.color.g=gray
  display.color.b=gray
EOH
  $query->delete('yarg scale');
} elsif ($query->param('fade to white')) {
  print PROG<<EOH;
  display.color.r=interpolate([254,000,000,000,000,255,255,255,255],(findgen(200)+1.)/25.)
  display.color.g=interpolate([255,000,255,255,255,255,200,080,000],(findgen(200)+1.)/25.)
  display.color.b=interpolate([255,255,255,127,000,000,000,000,000],(findgen(200)+1.)/25.)
EOH
  $query->delete('fade to white');
} else {
  print PROG<<EOH;
  display.color.r=interpolate([000,000,000,000,000,255,255,255,255],(findgen(200)+1.)/25.)
  display.color.g=interpolate([000,000,255,255,255,255,200,080,000],(findgen(200)+1.)/25.)
  display.color.b=interpolate([127,255,255,127,000,000,000,000,000],(findgen(200)+1.)/25.)
  display.color.b(0)=1
EOH
}

# force time label

if ($query->param('axis(0).x.title') =~ /SCET/) {
  $begtime = $query->param('column(0).tleft');
  $begtime = `/home/ljg/bin/ptime $begtime`; chop $begtime;
  $endtime = $query->param('column(0).tright');
  $endtime = `/home/ljg/bin/ptime $endtime`; chop $endtime;
  $query->param('axis(0).x.title', "\'$begtime    SCET    $endtime\'");
}

foreach $key ($query->param) {

  $value = $query->param($key);
# print LOG "$key = $value\n";
# should check key against valid list and value against expected type
  if (($key =~ /&/) || ($value =~ /&/)) {
    print PROG "\nFATAL_ERROR = 'ampersand in form data  . . . aborting!'\n";
    print PROG "exit\n";
    &PrintErrorExit ("$key = $value is invalid!");
  }
  if ($value eq 'init') { print PROG "init\n\n" }
  elsif ($key =~ /^\w+\(\d+\)\.query$/)
    { print PROG "$key = $key + \"$value\"\n" }
#    { print PROG "$key = $key + '; ' + \"$value\"\n" }
  elsif (($key =~ /\.t(left|right)$/) && ($value =~ /^[^'"].+[^'"]$/))
    { print PROG "$key = '$value'\n"; }
  else { print PROG "$key = $value\n" }

}

print PROG "go\nexit\n";

close(PROG);
*STDERR = $saveSTDERR;
close(LOG);
exit 0;

sub PrintHeader {
  print <<EOH;
Content-type: text/html

<HTML>
<HEAD><TITLE>das - data analysis system</TITLE></HEAD>
<BODY>
EOH
}

sub PrintTrailer {
  print <<EOH;
<HR>
<ADDRESS>
<A HREF="http://www-pw.physics.uiowa.edu/~ljg/me.html">
larry-granroth\@uiowa.edu</A>
</ADDRESS>
</BODY>
</HTML>
EOH
}

sub PrintErrorExit {
  &PrintHeader;
  print "<H2>ERROR: $_[0]</H2>\n";
  print "<tt>$referer</tt>\n";
  print "<HR><H3>Contents of log file:</H3><HR><PRE>\n";
  *STDERR = $saveSTDERR;
  close (LOG);
  if ( open (LOG, "</home/Web/tmp/$logfile") ) {
    while ( <LOG> ) { print $_; }
    close (LOG);
  } else { print "<EM>Cannot open log file.</EM>\n"; }
  print "\n</PRE>\n";
  &PrintTrailer;
  exit 0;
}
