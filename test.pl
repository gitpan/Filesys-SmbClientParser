# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..20\n"; }
END {print "not ok 1 Load test\n" unless $loaded;}
use Filesys::SmbClientParser;
$loaded = 1;
print "ok 1 Load test\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):


exit(0) unless (-e ".m");

my $total_test = 20;
my $courant = 1;
use POSIX;
open(F,".m") || die "Can't read .m\n";
my $l = <F>; chomp($l); 
my @l = split(/\t/, $l);
my $sha = $l[1];
my $smb = new Filesys::SmbClientParser
  (
   undef,
   (
    user       => $l[3],
    password   => $l[4],
    workgroup  => $l[2],
    host       => $l[0],
    share      => $l[1]
   )
  );

#$smb->Debug(10);

# create a test file
my $f = 'test_file_for_samba';
open(FILE,">$f") || die "can't create $f:$!\n";
print FILE "some data";
close(FILE);

# Create a directory
$smb->mkdir("toto") 
  ? ( ++$courant && print "ok 2 Create directory\n")
  : (print "not ok 2 Create directory: ", $smb->err, "\n");

# Chdir this dir
$smb->cd("toto") 
  ? ( ++$courant && print "ok 3 Chdir directory\n")
  : (print "not ok 3 Chdir directory: ", $smb->err, "\n");

# Put a file
$smb->put($f) 
  ? (++$courant && print "ok 4 Put file\n")
  : (print "not ok 4 Put file:", $smb->err, "\n");

# List content of directory
my @l = $smb->dir;         ;
if (!defined(@l)) { print "not ok 5 List file:", $smb->err, "\n"; }
($#l == 2) 
  ? (++$courant && print "ok 5 List file\n")
  : (print "not ok 5 List file: not 3 elem($#l)\n");

# Rename a file
$smb->rename($f,$f."_2") 
  ? (++$courant && print "ok 6 Rename file\n")
  : (print "not ok 6 Rename file ", $smb->err, "\n");

# Get a file
$smb->get($f."_2") 
  ? (++$courant && print "ok 7 Get file\n")
  : (print "not ok 7 Get file\n");

# Du the directory
($smb->du =~m!^0.0087!)
  ? (++$courant && print "ok 8 du\n")
  : (print "not ok 8 du:", $smb->du, " ", $smb->err, "\n");

# Unlink a file
$smb->del($f.'_2')
  ? ( ++$courant && print "ok 9 Unlink file\n")
  : (print "not ok 9 Unlink file ", $smb->err, "\n");

# Erase this directory
$smb->cd("..");
$smb->rmdir("toto")
  ? ( ++$courant && print "ok 10 Rm directory\n")
  : ( print "not ok 10 Rm directory ", $smb->err, "\n");

# Control current directory
($smb->pwd eq '\\'.$sha.'\\' )
  ? ( ++$courant && print "ok 11 Pwd\n")
  : ( print "not ok 11 Pwd ", $smb->pwd, $smb->err, "\n");

# Create a directory with (
$smb->mkdir("toto(tata")
  ? ( ++$courant && print "ok 12 Create directory with ( in name\n")
  : (print "not ok 12 Create directory: ", $smb->err, "\n");

# Try to recreate it
$smb->mkdir("toto(tata")
  ? (print "not ok 13 Create existant directory: ", $smb->err, "\n")
  : ( ++$courant && print "ok 13 Create existant directory\n");

# Chdir this dir
$smb->cd("toto(tata")
  ? ( ++$courant && print "ok 14 Chdir directory with ( in name\n")
  : (print "not ok 14 Chdir directory: ", $smb->err, "\n");

# Control current directory
($smb->pwd eq '\\'.$sha.'\\toto(tata\\')
  ? ( ++$courant && print "ok 15 Pwd with ( in name\n")
  : ( print "not ok 15 Pwd ", $smb->pwd, $smb->err, "\n");

# Erase this directory
$smb->cd("..");
$smb->rmdir("toto(tata")
  ? ( ++$courant && print "ok 16 Rm directory with ( in name\n")
  : ( print "not ok 16 Rm directory ", $smb->err, "\n");

# Erase unexistant directory
$smb->rmdir("toto(tata")
  ? ( print "not ok 17 Rm unexistant directory ", $smb->err, "\n")
  : ( ++$courant && print "ok 17 Rm unexistant directory\n");

# Unlink unexistant file
$smb->del("toto(tata")
  ? ( print "not ok 18 Rm unexistant file ", $smb->err, "\n")
  : ( ++$courant && print "ok 18 Rm unexistant file\n");

# Chdir unexistant directory
$smb->cd("toto(tata")
  ? ( print "not ok 19 Chdir unexistant directory ", $smb->err, "\n")
  : ( ++$courant && print "ok 19 Chdir unexistant directory\n");

# Get a file
$smb->get($f."toto(tata") 
  ? ( print "not ok 20 Get unexistant file ", $smb->err, "\n")
  : ( ++$courant && print "ok 20 Get unexistant file\n");

# Final result
($courant == $total_test) 
  ? ( print "All SMB test successful !\n\n")
  : ( print "Some SMB tests fails !\n\n");

unlink($f.'_2');
unlink($f);

print "There is a .m file in this directory with info about your params \n",
  "for you SMB server test. Think to remove it if you have finish \n",
  "with test.\n\nHere a dump of what I found on your smb network:\n",
  "(It can change with your smb server security level.)\n";

print "WORKGROUP:\n\tWg\tMaster\n";
foreach ($smb->GetGroups) {print "\t",$_->{name},"\t",$_->{master},"\n";}
print "HOSTS:\n\tName\t\tComment\n";
foreach ($smb->GetHosts)  {print "\t",$_->{name},"\t\t",$_->{comment},"\n";}
print "ON ",$smb->Host," i've found SHARE:\n\tName\n";
foreach ($smb->GetShr)    {print "\t",$_->{name},"\n";}
