#!/usr/bin/perl -Tw

$ENV{PATH}='';
$ENV{ENV}='';

use Test::More tests => 19;
use Filesys::SmbClientParser;

 SKIP: {
  skip('no smbclient tests defined with perl Makefile.PL', 19)
    if (! -e ".m");

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
ok( $smb->mkdir("toto") , 'Create directory');

# Chdir this dir
ok($smb->cd("toto") , "Chdir directory");

# Put a file
ok( $smb->put($f) , "Put file");

# List content of directory
@l = $smb->dir;
ok( @l && $#l ==2, "List file");

# Rename a file
ok ($smb->rename($f,$f."_2") , "Rename file");

# Get a file
ok ($smb->get($f."_2") , "Get file");

# Du the directory
ok ($smb->du =~m!^0.0087!, "du");

# Unlink a file
ok ($smb->del($f.'_2'), "Unlink file");

# Erase this directory
$smb->cd("..");
ok ($smb->rmdir("toto"), "Rm directory");

# Control current directory
ok ($smb->pwd eq '\\'.$sha.'\\' , "Pwd");

# Create a directory with (
ok( $smb->mkdir("toto(tata"), "Create directory with ( in name");

# Try to recreate it
ok(!$smb->mkdir("toto(tata"), "Create existant directory: ");

# Chdir this dir
ok($smb->cd("toto(tata"),"Chdir directory with ( in name");

# Control current directory
ok($smb->pwd eq '\\'.$sha.'\\toto(tata\\', "Pwd with ( in name");

# Erase this directory
$smb->cd("..");
ok( $smb->rmdir("toto(tata"),"Rm directory with ( in name");

# Erase unexistant directory
ok (! $smb->rmdir("toto(tata"),"Rm unexistant directory ");

# Unlink unexistant file
ok (! $smb->del("toto(tata"),"Rm unexistant file");

# Chdir unexistant directory
ok(! $smb->cd("toto(tata"), "Chdir unexistant directory ");

# Get a file
ok(! $smb->get($f."toto(tata"), "Get unexistant file ");

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

}
