package Filesys::SmbClientParser;

# Module Filesys::SmbClientParser : provide function to reach
# Samba ressources
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: SmbClientParser.pm,v $
# Revision 1.3  2001/04/19 17:01:10  alian
# - Remove CR/LF from 1.2 version (thanks to Sean Sirutis <seans@go2net.com>)
#
# Revision 1.2  2001/04/15 15:20:50  alian
# - Correct mput subroutine wrongly defined as mget
# - Added DEBUG level
# - Add pod doc for User, Password, Share, Host
# - Added rename and pwd method
# - Changed $recurse in mget so that it is always defined after testing
# - Added Auth() method, an alternative to explicit give of user/passwd
# (like -A option in smbclient)
# Thanks to brian.graham@centrelink.gov.au for this features
#
# Revision 0.3  2000/01/12 01:20:32  alian
# - Add methods mget and mput
#
# Revision 0.2  2000/11/20 19:08:11  Administrateur
# - Correct path of smbclient in new
# - Correct arg when no password
# - Correct error in synopsis

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 1.3 $ ' =~ /(\d+\.\d+)/)[0];

=head1 NAME

Filesys::SmbClientParser - Perl client to reach Samba ressources

=head1 SYNOPSIS

  use Filesys::SmbClientParser;
  my $smb = new Filesys::SmbClientParser;

  # Set parameters for connect
  $smb->User('Administrateur');
  $smb->Password('password');
  # Or like -A parameters:
  $smb->$auth("/home/alian/.smbpasswd");

  # Set host
  $smb->Host('jupiter');

  # List host available on this network machine
  my @l = $smb->GetHosts;
  foreach (@l) {print $_->{name},"\t",$_->{comment},"\n";}

  # List share disk available
  my @l = $smb->GetShr;
  foreach (@l) {print $_->{name},"\n";}

  # Choose a shared disk
  $smb->Share('games2');

  # List content
  my @l = $smb->dir;
  foreach (@l) {print $_->{name},"\n";}

  # Send a Winpopup message
  $smb->sendWinpopupMessage('jupiter',"Hello world !");

  # File manipulation
  $smb->cd('jdk1.1.8');
  $smb->get("COPYRIGHT");
  $smb->mkdir('tata');
  $smb->cd('tata');
  $smb->put("COPYRIGHT");
  $smb->del("COPYRIGHT");
  $smb->cd('..');
  $smb->rmdir('tata');

  # Archive method
  $smb->tar('c','/tmp/jdk.tar');
  $smb->cd('..');
  $smb->mkdir('tatz');
  $smb->cd('tatz');
  $smb->tar('x','/tmp/jdk.tar');

=head1 DESCRIPTION

SmbClientParser work with output of bin smbclient, so it doesn't work
on win platform. (but query of win platform work of course)

A best method is work with a samba shared librarie and xs language,
but on Nov.2000 (Samba version prior to 2.0.8) there is no public
interface and shared library defined in Samba projet.

Request has been submit and accepted on Samba-technical mailing list,
so a new module with name SmbClient will be done as soon as the public
interface has been known.

For Samba client prior to 2.0.8, use this module !

SmbClientParser is adapted from SMB.pm make by Remco van Mook
mook@cs.utwente.nl on smb2www project.

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=head1 SEE ALSO

smbclient(1) man pages.

=head1 DESCRIPTION

=head2 Objects methods

=over

=item new([$path_of_smbclient])

=cut

sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;
        if (!$_[0])
          {
          if (-x '/usr/bin/smbclient') {$self->{SMBLIENT} = '/usr/bin/smbclient';}
          elsif (-x '/usr/local/bin/smbclient') {$self->{SMBLIENT} = '/usr/local/bin/smbclient';}
          elsif (-x '/opt/bin/smbclient') {$self->{SMBLIENT} = '/opt/bin/smbclient';}
          else {goto 'ERROR';}
          }
        else
          {
          if (-x $_[0]) {$self->{SMBLIENT}=$_[0];}
          else {goto 'ERROR';}
        }
        $self->{DIR}='/';
        $self->{"DEBUG"} = 0;
        return $self;
        ERROR :
          die "Can't found smbclient.\nUse new('/path/of/smbclient')";
      }

=item Host($hostname)

Set the remote host to be used to $hostname.

=cut

sub Host {if ($_[1]) {$_[0]->{HOST}=$_[1];} return $_[0]->{HOST};}

=item User($username)

Set the username to be used to $username.

=cut

sub User { if ($_[1]) { $_[0]->{USER}=$_[1];} return $_[0]->{USER};}

=item Share($sharename)

Set the share to be used on the remote host to $sharename.

=cut

sub Share {if ($_[1]) {$_[0]->{SHARE}=$_[1];} return $_[0]->{SHARE};}

=item Password($password)

Set the password to be used to log on to the remote share $password.

=cut

sub Password {if ($_[1]) {$_[0]->{PASSWORD}=$_[1];} return $_[0]->{PASSWORD};}

=item Debug($debug)

Set the debug verbosity

    0 = no output
    1+ = more output

=cut

sub Debug {my ($self,$deb)=@_;  $self->{"DEBUG"} = $1 if ($deb =~ /^(\d+)$/);  return $self->{"DEBUG"};}


=item Auth($auth_file)

Use the file $auth_file for username and password.
This uses User and Password instead of -A to be backwards
compatible.

=cut

sub Auth
  {
  my ($self,$auth)=@_;
  print "In auth with $auth\n" if ($self->{DEBUG});
  if ($auth)
    {
    if (-r $auth)
      {
      open(AUTH, $auth) || die "Can't read $auth:$!\n";
      while (<AUTH>)
        {
        if ($_ =~ /^(\w+)\s*=\s*(\w+)\s*$/)
          {
          my $key = $1;
          my $value = $2;
          if ($key =~ /^password$/i) {$_[0]->Password($value);}
          elsif ($key =~ /^username$/i) {$_[0]->User($value);}
          }
        }
      close(AUTH);
      }
    }
  }

=back

=head2 Network methods

=over

=item GetShr

Return an array with sorted share listing

Syntax: @output = $smb->GetShr

array contains hashes; keys: name, type, comment

=cut

sub GetShr
  {
    my ($self,$host,$user,$pass) = @_;
    if (!$user) {$user=$self->User;}
    if (!$host) {$host=$self->Host;}
    if (!$pass) {$pass=$self->Password;}
    if (($user)&&($pass)) { $user = '-U '.$user.'%'.$pass; }
    elsif ($user) {$user = '-U '.$user}
    elsif (!$pass) {$user = "-N" }
    my @ret = ();
    my $lookup = $self->{SMBLIENT}." $user -L \'\\\\$host\' -d0";
    my ($err,@out) = $self->command($lookup,"getShr");
    my $line = shift @out;
    while ( (not $line =~ /^\s+Sharename/) and ($#out >= 0) ) {$line = shift @out;}
    if ($#out >= 0)
      {
        $line = shift @out;
        $line = shift @out;
        while ( (not $line =~ /^$/) and ($#out >= 0) )
          {
            if ( $line =~ /^\s+([\S ]*\S)\s+(Disk)\s+([\S ]*)/ )
              {
              my $rec = {};
              $rec->{name} = $1;
              $rec->{type} = $2;
              $rec->{comment} = $3;
              push @ret, $rec;
              }
            $line = shift @out;
          }
      }
    return sort byname @ret;
  }

=item GetHosts

Return an array with sorted host listing

Syntax: @output = $smb->GetHosts

array contains hashes; keys: name, comment

=cut

sub GetHosts
  {
    my ($self,$host,$user,$pass) = @_;
    if (!$user) {$user=$self->User;}
    if (!$host) {$host=$self->Host;}
    if (!$pass) {$pass=$self->Password;}
    if (($user)&&($pass)) { $user = '-U '.$user.'%'.$pass; }
    elsif ($user) {$user = '-U '.$user}
    elsif (!$pass) {$user = "-N" }
    my @ret = ();
    my $lookup = "$self->{SMBLIENT} $user -L \"$host\" -d0";
    my ($err,@out) = $self->command($lookup,"getHosts");
    my $line = shift @out;

    while ((not $line =~ /Server\s*Comment/) and ($#out >= 0) ) {$line = shift @out;}
    if ($#out >= 0)
      {
        $line = shift @out;$line = shift @out;
        while ((not $line =~ /^$/) and ($#out >= 0))
          {
          chomp($line);
            if ( $line =~ /^\t([\S ]*\S) {5,}(\S|.*)$/ )
              {
              my $rec = {};
              $rec->{name} = $1;
              $rec->{comment} = $2;
              push @ret, $rec;
              }
            $line = shift @out;
          }
      }
    return sort byname @ret;
  }


#=item GetGroups

#Return an array with sorted groups listing

#Syntax: @output = $smb->GetGroups ($host)

#array contains hashes; keys: name, master

#=cut

sub GetGroups
  {
  my ($self,$host)=@_;
    my @ret = ();
    my $lookup = $self->{SMBLIENT}." -L \"$host\" -d0";
    my ($err,@out) = $self->command($lookup,"getGroups");
    my $line = shift @out;
  while ((not $line =~ /^This machine has a workgroup list/) and ($#out >= 0) ) {$line = shift @out;}
    if ($#out >= 0)
      {
        $line = shift @out;
        $line = shift @out;
        $line = shift @out;
        $line = shift @out;
        while ((not $line =~ /^$/) and ($#out >= 0) )
          {
            if ( $line =~ /^\t([\S ]*\S) {2,}(\S[\S ]*)$/ )
              {
              my $rec = {};
              $rec->{name} = $1;
              $rec->{master} = $2;
              push @ret, $rec;
              }
            $line = shift @out;
          }
      }
    return sort byname @ret;
  }

=item sendWinpopupMessage($dest,$text)

This method allows you to send messages, using the "WinPopup" protocol,
to another computer. If the receiving computer is running WinPopup the
user will receive the message and probably a beep. If they are not
running WinPopup the message will be lost, and no error message will occur.

The message is also automatically truncated if the message is over
1600 bytes, as this is the limit of the protocol.

Parameters :

 $dest: name of host or user to send message
 $text: text to send

=cut

sub sendWinpopupMessage
  {
    my ($self, $dest, $text) = @_;
    my $args = "/bin/echo \"$text\" | ".$self->{SMBLIENT}." -M $dest";
    $self->command($args,"winpopup message");
  }

=back

=head2 Operations

=over

=item cd [$dir]

cd [directory name]
If "directory name" is specified, the current working directory on the server
will be changed to the directory specified. This operation will fail if for
any reason the specified directory is inaccessible. Return list.

If no directory name is specified, the current working directory on the server
will be reported.

=cut

sub cd
  {
    my ($self, $dir, $host, $share, $user, $pass ) = @_;
    if (!$user) {$user=$self->User;}
    if (!$host) {$host=$self->Host;}
    if (!$share){$share=$self->Share;}
    if (!$pass) {$pass=$self->Password;}
    if (($user)&&($pass)) { $user = '-U '.$user.'%'.$pass; }
    elsif ($user) {$user = '-U '.$user}
    elsif (!$pass) {$user = "-N" }
  if ($dir)
    {
    my $args = $self->{SMBLIENT}." \"//$host/$share\" $user -d0 -c 'cd $dir' -D $self->{DIR}";
    my @l = $self->command($args,"cd");
    if ($dir=~/^\//) {$_[0]->{DIR}=$dir;}
    elsif ($dir=~/^..$/) {if ($_[0]->{DIR}=~/(.*\/)(.+?)$/) {$_[0]->{DIR}=$1;}}
    else {$_[0]->{DIR}.='/'.$dir;}
    }
  else {return $_[0]->{DIR};}
  }

=item dir

Return an array with sorted dir and filelisting

Syntax: @output = $smb->dir (host,share,dir,user,pass)

Array contains hashes; keys: name, attr, size, date

=cut

sub dir
  {
    my ($self, $dir, $host, $share, $user, $pass ) = @_;
    my (@dir,@files);
    if (!$user) {$user=$self->User;}
    if (!$host) {$host=$self->Host;}
    if (!$share){$share=$self->Share;}
    if (!$pass) {$pass=$self->Password;}
    if (!$dir) {$dir=$self->{DIR};}
    if (($user)&&($pass)) { $user = '-U '.$user.'%'.$pass; }
    elsif ($user) {$user = '-U '.$user}
    elsif (!$pass) {$user = "-N" }
    my $lookup = $self->{SMBLIENT}." \"//$host/$share\" $user -d0 -c 'ls $dir/*'";
    my ($err,@out) = $self->command($lookup,"dir");
    foreach my $line ( @out )
      {
        if ($line =~ /^  ([\S ]*\S|[\.]+) {5,}([HDRSA]+) +([0-9]+)  (\S[\S ]+\S)$/g)
          {
            my $rec = {};
            $rec->{name} = $1;
            $rec->{attr} = $2;
            $rec->{size} = $3;
            $rec->{date} = $4;
            if ($rec->{attr} =~ /D/) {push @dir, $rec;}
            else {push @files, $rec;}
          }
        elsif ($line =~ /^  ([\S ]*\S|[\.]+) {6,}([0-9]+)  (\S[\S ]+\S)$/)
          {
            my $rec = {};
            $rec->{name} = $1;
            $rec->{attr} = "";
            $rec->{size} = $2;
            $rec->{date} = $3;
            push @files, $rec; # No attributes at all, so it must be a file
          }
      }
    my @ret = sort byname @dir;
    @files = sort byname @files;
    foreach my $line ( @files ) {push @ret, $line;}
    return @ret;
  }

=item mkdir($masq)

mkdir <mask>
Create a new directory on the server (user access privileges
permitting) with the specified name.

=cut

sub mkdir
  {
    my ($self, $masq,$dir, $host, $share, $user, $pass ) = @_;
    my $commande = "mkdir $masq";
  $self->operation($commande,$dir, $host, $share, $user, $pass);
  }

=item rmdir($masq)

Remove the specified directory (user access privileges
permitting) from the server.

=cut

sub rmdir
  {
    my ($self, $masq,$dir, $host, $share, $user, $pass ) = @_;
    my $commande = "rmdir $masq";
  $self->operation($commande,$dir, $host, $share, $user, $pass);
  }

=item get($file, $target, [$dir])

Gets the file $file, using $user and $pass, to $target on courant SMB
server and return the error code.
If $target is unspecified, courant directory will be used
For use STDOUT, set target to '-'.

Syntax: $error = $smb->get ($file,$target,[$dir])

=cut

sub get
  {
    my ($self, $file, $target,$dir, $host, $share, $user, $pass) = @_;
    $file =~ s/^(.*)\/([^\/]*)$/$1$2/ ;
    my $commande = "get \"$file\" $target";
  return $self->operation($commande,$dir, $host, $share, $user, $pass);
  }

=item mget($file,[$recurse])

Gets file(s) $file on current SMB server,directory and return
the error code. If multiple file, push an array ref as first parameter
or pattern * or file separated by space

Syntax:

  $error = $smb->mget ('file'); #or
  $error = $smb->mget (join(' ',@file); #or
  $error = $smb->mget (\@file); #or
  $error = $smb->mget ("*",1);

=cut

sub mget
  {
  my ($self, $file,$recurse) = @_;
  $file = ref($file) eq 'ARRAY' ? join (' ',@$file) : $file;
  $recurse ? $recurse = 'recurse' : $recurse = "" ;
  my $commande = "prompt off; $recurse; mget $file";
  return $self->operation($commande);
  }

=item put$($orig,$file,[$dir])

Puts the file $orig to $file, using $user and $pass on courant SMB
server and return the error code.
If $orig is unspecified, STDIN is used (-).

Syntax: $error = $smb->PutFile ($host,$share,$file,$user,$pass,$orig)

=cut

sub put
  {
    my ($self,$orig,$file,$dir, $host, $share, $user, $pass) = @_;
    $file =~ s/^(.*)\/([^\/]*)$/$1$2/ ;
    my $commande = "put \"$orig\" \"$file\"";
    return $self->operation($commande,$dir, $host, $share, $user, $pass);
  }

=item mput($file,[$recurse])

Puts file(s) $file on current SMB server,directory and return
the error code. If multiple file, push an array ref as first parameter
or pattern * or file separated by space

Syntax:

  $error = $smb->mput ('file'); #or
  $error = $smb->mput (join(' ',@file); #or
  $error = $smb->mput (\@file); #or
  $error = $smb->mput ("*",1);

=cut

sub mput
  {
  my ($self, $file,$recurse) = @_;
  $file = ref($file) eq 'ARRAY' ? join (' ',@$file) : $file;
  $recurse = 'recurse' if ($recurse);
  my $commande = "prompt off; $recurse; mput $file";
  return $self->operation($commande);
  }


=item del($mask)

del <mask>
The client will request that the server attempt to delete
all files matching "mask" from the current working directory
on the server

=cut

sub del
  {
      my ($self, $masq,$dir, $host, $share, $user, $pass ) = @_;
      my $commande = "del $masq";
      $self->operation($commande,$dir, $host, $share, $user, $pass);
  }


=item rename($source, $target)

rename source target
The file matched by mask will be moved to target.  These names
can be in differnet directories.  It returns a return value.

=cut

sub rename
{
    my ($self, $source, $target) = @_;
    my $command = "rename $source $target";
    my ($rc) = $self->operation($command);
    return $rc;
}

=item pwd()

pwd
Returns the present working directory on the remote system.  If
there is an error it returns undef.

=cut

sub pwd
{
    my ($self) = @_;
    my $command = "pwd";
    my ($error, @vars) = $self->operation($command);

    foreach (@vars)
      {if ($_ =~ /^\s*Current directory is \\\\.*?(\\.*)$/) {return $1; }}
    return undef;
}



=back

=head2 Archives methods

=over

=item tar($command,$target)

Execute TAR commande on //$host/$share/$dir, using $user and $pass, to $target.
and return the error code. If $target is unspecified, current directory will be
used.

Syntax: $error = $smb->tar ($command) where command in ('x','c',...) See smbclient
man page

=cut

sub tar
  {
    my ($self, $command, $target, $dir, $host, $share, $user, $pass) = @_;
    #if ( $target eq "") { $target = "-" };
    if (!$user) {$user=$self->User;}
    if (!$host) {$host=$self->Host;}
    if (!$share){$share=$self->Share;}
    if (!$pass) {$pass=$self->Password;}
    if (!$dir) {$dir=$self->{DIR};}
    if (($user)&&($pass)) { $user = '-U \''.$user.'%'.$pass."'"; }
    elsif ($user) {$user = '-U '.$user;}
    elsif (!$pass) {$user = "-N" }
    my $args = $self->{SMBLIENT}. " //$host/$share $user -d0 -D $dir -T$command $target";
    $self->command($args,"-T$command $target");
  }

=back

=head2 Private methods

=over

=item byname

sort an array of hashes by $_->{name} (for GetSMBDir et al)

=cut

sub byname {(lc $a->{name}) cmp (lc $b->{name})}

=item operation(...)

=cut

sub operation
  {
    my ($self,$command,$dir, $host, $share, $user, $pass ) = @_;
    if (!$user) {$user=$self->User;}
    if (!$host) {$host=$self->Host;}
    if (!$share){$share=$self->Share;}
    if (!$pass) {$pass=$self->Password;}
    if (!$dir) {$dir=$self->{DIR};}
    if (($user)&&($pass)) { $user = '-U '.$user.'%'.$pass; }
    elsif ($user) {$user = '-U '.$user;}
    elsif (!$pass) {$user = "-N" }
    my $args = $self->{SMBLIENT}.' //'.$host.'/'.$share.' '.$user." -d0 -c \"$command\" -D $dir";
    return $self->command($args,$command);
  }

=item command($args,$command)

=cut

sub command
  {
    my ($self,$args,$command)=@_;
    if ($self->{"DEBUG"} > 0)
    {
  print "$args\n";
    }
    my $error=0;
    my @var = `$args`;# or die "system $args failed: $?,$!\n";
    my $var=join(' ',@var ) ;
    if ($var=~/ERRnoaccess/)   {print "Error $command: permission denied\n";$error=1;}
    elsif ($var=~/ERRbadfunc/)   {print "Error $command: Invalid function.\n";$error=1;}
    elsif ($var=~/ERRbadfile/)   {print "Error $command: File not found.\n";$error=1;}
    elsif ($var=~/ERRbadpath/)   {print "Error $command: Directory invalid.\n";$error=1;}
    elsif ($var=~/ERRnofids/)   {print "Error $command: No file descriptors available\n";$error=1;}
    elsif ($var=~/ERRnoaccess/)   {print "Error $command: Access denied.\n";$error=1;}
    elsif ($var=~/ERRbadfid/)   {print "Error $command: Invalid file handle.\n";$error=1;}
    elsif ($var=~/ERRbadmcb/)   {print "Error $command: Memory control blocks destroyed.\n";$error=1;}
    elsif ($var=~/ERRnomem/)   {print "Error $command: Insufficient server memory to perform the requested function.\n";$error=1;}
    elsif ($var=~/ERRbadmem/)   {print "Error $command: Invalid memory block address.\n";$error=1;}
    elsif ($var=~/ERRbadenv/)   {print "Error $command: Invalid environment.\n";$error=1;}
    elsif ($var=~/ERRbadformat/)   {print "Error $command: Invalid format.\n";$error=1;}
    elsif ($var=~/ERRbadaccess/)   {print "Error $command: Invalid open mode.\n";$error=1;}
    elsif ($var=~/ERRbaddata/)   {print "Error $command: Invalid data.\n";$error=1;}
    elsif ($var=~/ERRbaddrive/)   {print "Error $command: Invalid drive specified.\n";$error=1;}
    elsif ($var=~/ERRremcd/)   {print "Error $command: A Delete Directory request attempted  to  remove  the  server's  current directory.\n";$error=1;}
    elsif ($var=~/ERRdiffdevice/)   {print "Error $command: Not same device.\n";$error=1;}
    elsif ($var=~/ERRnofiles/)   {print "Error $command: A File Search command can find no more files matching the specified criteria.\n";$error=1;}
    elsif ($var=~/ERRbadshare/)   {print "Error $command: The sharing mode specified for an Open conflicts with existing  FIDs  on the file.\n";$error=1;}
    elsif ($var=~/ERRlock/)   {print "Error $command: A Lock request conflicted with an existing lock or specified an  invalid mode,  or an Unlock requested attempted to remove a lock held by another process.\n";$error=1;}
    elsif ($var=~/ERRunsup/)   {print "Error $command: The operation is unsupported\n";$error=1;}
    elsif ($var=~/ERRnosuchshare/)  {print "Error $command: You specified an invalid share name\n";$error=1;}
    elsif ($var=~/ERRfilexists/)   {print "Error $command: The file named in a Create Directory, Make  New  File  or  Link  request already exists.\n";$error=1;}
    elsif ($var=~/ERRbadpipe/)   {print "Error $command: Pipe invalid.\n";$error=1;}
    elsif ($var=~/ERRpipebusy/)   {print "Error $command: All instances of the requested pipe are busy.\n";$error=1;}
    elsif ($var=~/ERRpipeclosing/)  {print "Error $command: Pipe close in progress.\n";$error=1;}
    elsif ($var=~/ERRnotconnected/)  {print "Error $command: No process on other end of pipe.\n";$error=1;}
    elsif ($var=~/ERRmoredata/)   {print "Error $command: There is more data to be returned.\n";$error=1;}
    elsif ($var=~/ERRinvgroup/)   {print "Error $command: Invalid workgroup (try the -W option)\n";$error=1;}
    elsif ($var=~/ERRerror/)   {print "Error $command: Non-specific error code.\n";$error=1;}
    elsif ($var=~/ERRbadpw/)   {print "Error $command: Bad password - name/password pair in a Tree Connect or Session Setup are invalid.\n";$error=1;}
    elsif ($var=~/ERRbadtype/)   {print "Error $command: reserved.\n";$error=1;}
    elsif ($var=~/ERRaccess/)   {print "Error $command: The requester does not have  the  necessary  access  rights  within  the specified  context for the requested function. The context is defined by the TID or the UID.\n";$error=1;}
    elsif ($var=~/ERRinvnid/)   {print "Error $command: The tree ID (TID) specified in a command was invalid.\n";$error=1;}
    elsif ($var=~/ERRinvnetname/)   {print "Error $command: Invalid network name in tree connect.\n";$error=1;}
    elsif ($var=~/ERRinvdevice/)   {print "Error $command: Invalid device - printer request made to non-printer connection or  non-printer request made to printer connection.\n";$error=1;}
    elsif ($var=~/ERRqfull/)   {print "Error $command: Print queue full (files) -- returned by open print file.\n";$error=1;}
    elsif ($var=~/ERRqtoobig/)   {print "Error $command: Print queue full -- no space.\n";$error=1;}
    elsif ($var=~/ERRqeof/)   {print "Error $command: EOF on print queue dump.\n";$error=1;}
    elsif ($var=~/ERRinvpfid/)   {print "Error $command: Invalid print file FID.\n";$error=1;}
    elsif ($var=~/ERRsmbcmd/)   {print "Error $command: The server did not recognize the command received.\n";$error=1;}
    elsif ($var=~/ERRsrverror/)   {print "Error $command: The server encountered an internal error, e.g., system file unavailable.\n";$error=1;}
    elsif ($var=~/ERRfilespecs/)  {print "Error $command: The file handle (FID) and pathname parameters contained an invalid  combination of values.\n";$error=1;}
    elsif ($var=~/ERRreserved/)   {print "Error $command: reserved.\n";$error=1;}
    elsif ($var=~/ERRbadpermits/)   {print "Error $command: The access permissions specified for a file or directory are not a valid combination.  The server cannot set the requested attribute.\n";$error=1;}
    elsif ($var=~/ERRreserved/)   {print "Error $command: reserved.\n";$error=1;}
    elsif ($var=~/ERRsetattrmode/)  {print "Error $command: The attribute mode in the Set File Attribute request is invalid.\n";$error=1;}
    elsif ($var=~/ERRpaused/)   {print "Error $command: Server is paused.\n";$error=1;}
    elsif ($var=~/ERRmsgoff/)   {print "Error $command: Not receiving messages.\n";$error=1;}
    elsif ($var=~/ERRnoroom/)   {print "Error $command: No room to buffer message.\n";$error=1;}
    elsif ($var=~/ERRrmuns/)   {print "Error $command: Too many remote user names.\n";$error=1;}
    elsif ($var=~/ERRtimeout/)   {print "Error $command: Operation timed out.\n";$error=1;}
    elsif ($var=~/ERRnoresource/)   {print "Error $command: No resources currently available for request.\n";$error=1;}
    elsif ($var=~/ERRtoomanyuids/)  {print "Error $command: Too many UIDs active on this session.\n";$error=1;}
    elsif ($var=~/ERRbaduid/)   {print "Error $command: The UID is not known as a valid ID on this session.\n";$error=1;}
    elsif ($var=~/ERRusempx/)   {print "Error $command: Temp unable to support Raw, use MPX mode.\n";$error=1;}
    elsif ($var=~/ERRusestd/)   {print "Error $command: Temp unable to support Raw, use standard read/write.\n";$error=1;}
    elsif ($var=~/ERRcontmpx/)   {print "Error $command: Continue in MPX mode.\n";$error=1;}
    elsif ($var=~/ERRreserved/)   {print "Error $command: reserved.\n";$error=1;}
    elsif ($var=~/ERRreserved/)   {print "Error $command: reserved.\n";$error=1;}
    elsif ($var=~/ERRnosupport/)   {print "Function not supported.\n";$error=1;}
    elsif ($var=~/ERRnowrite/)   {print "Error $command: Attempt to write on write-protected diskette.\n";$error=1;}
    elsif ($var=~/ERRbadunit/)   {print "Error $command: Unknown unit.\n";$error=1;}
    elsif ($var=~/ERRnotready/)   {print "Error $command: Drive not ready.\n";$error=1;}
    elsif ($var=~/ERRbadcmd/)   {print "Error $command: Unknown command.\n";$error=1;}
    elsif ($var=~/ERRdata/)   {print "Error $command: Data error (CRC).\n";$error=1;}
    elsif ($var=~/ERRbadreq/)   {print "Error $command: Bad request structure length.\n";$error=1;}
    elsif ($var=~/ERRseek/)   {print "Error $command: Seek error.\n";$error=1;}
    elsif ($var=~/ERRbadmedia/)   {print "Error $command: Unknown media type.\n";$error=1;}
    elsif ($var=~/ERRbadsector/)   {print "Error $command: Sector not found.\n";$error=1;}
    elsif ($var=~/ERRnopaper/)   {print "Error $command: Printer out of paper.\n";$error=1;}
    elsif ($var=~/ERRwrite/)   {print "Error $command: Write fault.\n";$error=1;}
    elsif ($var=~/ERRread/)   {print "Error $command: Read fault.\n";$error=1;}
    elsif ($var=~/ERRgeneral/)   {print "Error $command: General failure.\n";$error=1;}
    elsif ($var=~/ERRbadshare/)   {print "Error $command: An open conflicts with an existing open.\n";$error=1;}
    elsif ($var=~/ERRlock/)   {print "Error $command: A Lock request conflicted with an existing lock or specified an invalid mode, or an Unlock requested attempted to remove a lock held by another process.\n";$error=1;}
    elsif ($var=~/ERRwrongdisk/)   {print "Error $command: The wrong disk was found in a drive.\n";$error=1;}
    elsif ($var=~/ERRFCBUnavail/)   {print "Error $command: No FCBs are available to process request.\n";$error=1;}
    elsif ($var=~/ERRsharebufexc/)  {print "Error $command: A sharing buffer has been exceeded.\n";$error=1;}        
    elsif ($var=~/ERR/)     {print "Error $command: reserved.\n";$error=1;}
  return ($error,@var);
  }

=back

=cut
