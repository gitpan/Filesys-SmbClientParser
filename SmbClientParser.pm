package Filesys::SmbClientParser;

# Module Filesys::SmbClientParser : provide function to reach
# Samba ressources
# Copyright 2000-2002 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: SmbClientParser.pm,v $
# Revision 2.4  2002/11/08 23:51:19  alian
# - Correct a bug that didn't set smbclient path when pass as arg of new.
# (thanks to Andreas Dahl for report and patch).
# - Correct a bug in error parsing that disable use of file or dir with
# ERR in his name. Eg: JERRY. (Thanks to Jason Sloderbeck for report).
#
# Revision 2.3  2002/08/13 13:44:00  alian
# - Update smbclient detection (scan path and try wich)
# - Update get, du method for perl -w mode
# - Update command method for perl -T mode
# - Update all exec command: add >&1 for Solaris output on STDERR
# - Add NT_STATUS_ message detection for error
#
# Revision 2.2  2002/08/08 23:28:22  alian
# - Correction bug sur option -N de smbclient (tks to reiffer@kph.uni-mainz.de)
#
# Revision 2.1  2002/04/11 23:39:34  alian
# - Add du method  (thanks to Ben Scott <scotsman@CSUA.Berkeley.EDU>)
# - Correct pwd method
#
# Revision 2.0  2002/01/25 11:46:41  alian
# - Add IP parameter
# - Add some quote for space in name usage
# (tks to Mike Rosack for his BuzzSearch version)
# - Update POD documentation
# - Update all return code error: undef is always return if error,
# and method err return last string error find.
# This is why I pass to 2.0 release.
# - Correct no error code in mkdir, delete
# - Debug GetGroups method
# - Debug case if share is defined in GetShare or GetHosts
# - Add hash parameter to constructor


use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 2.4 $ ' =~ /(\d+\.\d+)/)[0];

#------------------------------------------------------------------------------
# new
#------------------------------------------------------------------------------
sub new 
  {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    sub search_it {
      my $self = shift;
      foreach my $p (@_) {	
	if (-x "$p/smbclient") {
	  $self->{SMBLIENT} = $p."/smbclient";
	  last;
	}
      }
    }
    # Search path of smbclient
    my $pat = shift;
    my @common = qw!/usr/bin /usr/local/bin /opt/bin /opt/local/bin 
                    /usr/local/samba/bin /usr/pkg/bin!;
    if (!$pat or !(-x $pat)) {
      # Try common location
      $self->search_it(@common);
      # Try path
      $self->search_it(split(/:/,$ENV{PATH})) if (!-x $self->{SMBLIENT});
      # May be taint mode ...
      $self->search_it(split(/:/,`which smbclient`)) 
	if (!-x $self->{SMBLIENT});
      goto 'ERROR' if (!-x $self->{SMBLIENT});
    }
    else { $self->{SMBLIENT} = $pat;}
    # fix others parameters
    my %ref = @_;
    $self->Host($ref{host}) if ($ref{host});
    $self->User($ref{user}) if ($ref{user});
    $self->Share($ref{share}) if ($ref{share});
    $self->Password($ref{password}) if ($ref{password});
    $self->Workgroup($ref{workgroup}) if ($ref{workgroup});
    $self->IpAdress($ref{ipadress}) if ($ref{ipadress});
    $self->{DIR}='/';
    $self->{"DEBUG"} = 0;
    return $self;
    ERROR :
      die "Can't found smbclient.\nUse new('/path/of/smbclient')";
  }

#------------------------------------------------------------------------------
# Fields methods
#------------------------------------------------------------------------------
sub Host {if ($_[1]) {$_[0]->{HOST}=$_[1];} return $_[0]->{HOST};}
sub User { if ($_[1]) { $_[0]->{USER}=$_[1];} return $_[0]->{USER};}
sub Share {if ($_[1]) {$_[0]->{SHARE}=$_[1];} return $_[0]->{SHARE};}
sub Password {if ($_[1]) {$_[0]->{PASSWORD}=$_[1];} return $_[0]->{PASSWORD};}
sub Workgroup {if ($_[1]) {$_[0]->{WG}=$_[1];} return $_[0]->{WG};}
sub IpAdress {if ($_[1]) {$_[0]->{IP}=$_[1];} return $_[0]->{IP};}
sub LastResponse 
  {if ($_[1]) {$_[0]->{LAST_REP}=$_[1];} return $_[0]->{LAST_REP};}
sub err 
  {if ($_[1]) {$_[0]->{LAST_ERR}=$_[1];} return $_[0]->{LAST_ERR};}

#------------------------------------------------------------------------------
# Debug mode
#------------------------------------------------------------------------------
sub Debug 
  {
    my ($self,$deb)=@_;  
    $self->{"DEBUG"} = $1 if ($deb =~ /^(\d+)$/);  
    return $self->{"DEBUG"};
  }

#------------------------------------------------------------------------------
# Auth
#------------------------------------------------------------------------------
sub Auth
  {
    my ($self,$auth)=@_;
    print "In auth with $auth\n" if ($self->{DEBUG});
    if ($auth)
      {
	if (-r $auth) {
	  open(AUTH, $auth) || die "Can't read $auth:$!\n";
	  while (<AUTH>) {
	    if ($_ =~ /^(\w+)\s*=\s*(\w+)\s*$/) {
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


#------------------------------------------------------------------------------
# _List
#------------------------------------------------------------------------------
sub _List
  {
    my ($self, $host, $user, $pass, $wg, $ip) = @_;
    if (!$host) {$host=$self->Host;} undef $self->{HOST};
    my $tmp = $self->Share; undef $self->{SHARE};
    my $commande = "-L '\\\\$host' ";
    $self->commande($commande, undef, undef, undef, $user, $pass, $wg, $ip)
	|| return undef;
    $self->Host($host); $self->Share($tmp);
    return $self->LastResponse;
  }

#------------------------------------------------------------------------------
# GetShr
#------------------------------------------------------------------------------
sub GetShr
  {
    my ($self, $host, $user, $pass, $wg, $ip) = @_;
    my $out = _List(@_) || return undef;
    my @out = @$out;
    my @ret = ();
    my $line = shift @out;
    while ( (not $line =~ /^\s+Sharename/) and ($#out >= 0) ) 
      {$line = shift @out;}
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


#------------------------------------------------------------------------------
# GetHosts
#------------------------------------------------------------------------------
sub GetHosts
  {
    my ($self,$host,$user,$pass,$wg,$ip) = @_;
    my $out = _List(@_) || return undef;
    my @out = @$out;
    my @ret = ();
    my $line = shift @out;

    while ((not $line =~ /Server\s*Comment/) and ($#out >= 0) ) 
      {$line = shift @out;}
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

#------------------------------------------------------------------------------
# GetGroups
#------------------------------------------------------------------------------
sub GetGroups
  {
    my ($self,$host,$user,$pass,$wg,$ip) = @_;
    my $out = _List(@_) || return undef;
    my @ret = ();
    my @out = @$out;
    my $line = shift @out;
    while ((not $line =~ /Workgroup/) and	($#out >= 0) ) 
	{$line = shift @out;}
    if ($#out >= 0)
      {
        $line = shift @out;
        while ((not $line =~ /^$/) and ($#out >= 0) )
          {
		$line = shift @out;
            if ( $line =~ /^\t([\S ]*\S) {2,}(\S[\S ]*)$/ )
              {
              my $rec = {};
              $rec->{name} = $1;
              $rec->{master} = $2;
              push @ret, $rec;
              }
          }
      }
    return sort byname @ret;
  }

#------------------------------------------------------------------------------
# sendWinpopupMessage
#------------------------------------------------------------------------------
sub sendWinpopupMessage
  {
    my ($self, $dest, $text) = @_;
    my $args = "/bin/echo \"$text\" | ".$self->{SMBLIENT}." -M $dest";
    return $self->command($args,"winpopup message");
  }

#------------------------------------------------------------------------------
# cd
#------------------------------------------------------------------------------
sub cd
  {
    my $self = shift;
    my $dir  = shift;
    if ($dir)
      {
	my $commande;
	if ($dir ne ".."){$commande = "cd \"$dir\""; }
	else { $commande = "cd .."; }
	$self->operation($commande, undef, @_) || return undef;
	if ($dir=~/^\//) {$self->{DIR}=$dir;}
	elsif ($dir=~/^..$/) 
	  {if ($self->{DIR}=~/(.*\/)(.+?)$/) {$self->{DIR}=$1;}}
	elsif($self->{DIR}=~/\/$/){ $self->{DIR}.=$dir; }
	else{$self->{DIR}.='/'.$dir;}
	return 1;
    }
    else {return $self->{DIR};}
  }

#------------------------------------------------------------------------------
# dir
#------------------------------------------------------------------------------
sub dir
  {
    my $self = shift;
    my $dir  = shift;
    my (@dir,@files);
    if (!$dir) {$dir=$self->{DIR};}
    my $cmd = "ls $dir/*";
    $self->operation($cmd,undef,@_) || return undef;
    my $out = $self->LastResponse;
    foreach my $line ( @$out )
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
    @ret= (@ret, @files );
    return @ret;
  }

#------------------------------------------------------------------------------
# mkdir
#------------------------------------------------------------------------------
sub mkdir
  {
    my $self = shift;
    my $masq = shift;
    my $commande = "mkdir $masq";
    return $self->operation($commande,@_);
  }

#------------------------------------------------------------------------------
# get
#------------------------------------------------------------------------------
sub get  {
  my $self   = shift; 
  my $file   = shift;
  my $target = shift;
  $file =~ s/^(.*)\/([^\/]*)$/$1$2/ ;
  my $commande = "get \"$file\" ";
  $commande.=$target if ($target);
  return $self->operation($commande,@_);
}

#------------------------------------------------------------------------------
# mget
#------------------------------------------------------------------------------
sub mget
  {
    my $self = shift;
    my $file = shift;
    my $recurse = shift;
    $file = ref($file) eq 'ARRAY' ? join (' ',@$file) : $file;
    $recurse ? $recurse = 'recurse;' : $recurse = " " ;
    my $commande = "prompt off; $recurse mget $file";
    return $self->operation($commande,@_);
  }

#------------------------------------------------------------------------------
# put
#------------------------------------------------------------------------------
sub put
  {
    my $self = shift;
    my $orig = shift;
    my $file = shift || $orig;
    $file =~ s/^(.*)\/([^\/]*)$/$1$2/ ;
    my $commande = "put \"$orig\" \"$file\"";
    return $self->operation($commande,@_);
  }


#------------------------------------------------------------------------------
# mput
#------------------------------------------------------------------------------
sub mput
  {
  my $self = shift;
  my $file = shift;
  my $recurse = shift;
  $file = ref($file) eq 'ARRAY' ? join (' ',@$file) : $file;
  $recurse ? $recurse = 'recurse;' : $recurse = " " ;
  my $commande = "prompt off; $recurse mput $file";
  return $self->operation($commande,@_);
  }

#------------------------------------------------------------------------------
# del
#------------------------------------------------------------------------------
sub del
  {
    my $self = shift;
    my $masq = shift;
    my $commande = "del $masq";
    return $self->operation($commande,@_);
  }

#------------------------------------------------------------------------------
# rmdir
#------------------------------------------------------------------------------
sub rmdir
  {
    my $self = shift;
    my $masq = shift;
    my $commande = "rmdir $masq";
    return $self->operation($commande,@_);
  }

#------------------------------------------------------------------------------
# rename
#------------------------------------------------------------------------------
sub rename
  {
    my $self   = shift;
    my $source = shift;
    my $target = shift;
    my $command = "rename $source $target";
    return $self->operation($command,@_);
  }

#------------------------------------------------------------------------------
# pwd
#------------------------------------------------------------------------------
sub pwd
  {
    my $self = shift;
    my $command = "pwd";
    if ($self->operation($command,@_))
	{
	  my $out = $self->LastResponse;
	  foreach ( @$out )
	    {
		if ($_ =~m !^\s*Current directory is \\\\[^\\]*(\\.*)$!)
		  {return $1; }
	    }
	}
    return undef;
  }

#------------------------------------------------------------------------------
# du
#------------------------------------------------------------------------------
sub du
  {
    my $self = shift;
    my $dir  = shift;
    my $blk = shift || 'k';

    my $blksize;
    if ($blk !~ /\D/ && $blk > 0)
      {
        $blksize = $blk;
      }
    elsif ($blk =~ /^([kbsmg])/i)
      {
        $blksize = 512                  if ($blk =~ /b/i); ## Posix blocks
        $blksize = 1024                 if ($blk =~ /k/i); ## 1Kbyte blocks
        $blksize = 1024*512             if ($blk =~ /s/i); ## Samba blocks
        $blksize = 1024*1024            if ($blk =~ /m/i); ## 1Mbyte blocks
        $blksize = 1024*1024*1024       if ($blk =~ /g/i); ## 1Gbyte blocks
      }
    else
      {die "Invalid argument for blocksize: $blk\n";}
    $blksize ||= 1024;          ## Default to 1Kbyte blocks

    $dir =~ s#(.*)(^|/)\.(/|$)(.*)#$1$2$4#g if ($dir);
    $dir = $self->{DIR} unless ($dir);

    my $cmd = "du $dir/*";
    $self->operation($cmd,undef,@_) || return undef;
    my $out = $self->LastResponse;
    my $rec = {};
    foreach my $line ( @$out )
      {
        if ($line =~ /^\s*(\d+)\D+(\d+)\D+(\d+)\D+$/)
          {
            my $blksz = (defined $2) ? $2 : 512 * 1024;
            $rec->{ublks} = $1 * ($blksz / $blksize);
            $rec->{fblks} = $3 * ($blksz / $blksize);
            $rec->{blksz} = $blksize;
          }
        if ($line =~ /^\D+:\s+(\d+)\s*$/)
          {
            $rec->{usage} = $1 / $blksize;
          }
      }

    if (wantarray()) { return values %$rec; }
    else { return $rec->{usage}; }
  }

#------------------------------------------------------------------------------
# tar
#------------------------------------------------------------------------------
sub tar
  {
    my $self    = shift;
    my $command = shift;
    my $target  = shift;
    my $dir = shift || $self->{DIR}; 
    $self->{DIR}=undef;
    my $cmd = " -T$command $target $dir";
    $self->{DIR}=$dir;
    return $self->commande($cmd,undef,@_);
  }

#------------------------------------------------------------------------------
# operation
#------------------------------------------------------------------------------
sub operation
  {
    my ($self,$command,$dir, $host, $share, $user, $pass, $wg, $ip) = @_;
    if (!$user) {$user=$self->User;}
    if (!$host) {$host=$self->Host;}    
    if (!$share){$share=$self->Share;}
    if (!$pass) {$pass=$self->Password;}
    if (!$dir) {$dir=$self->{DIR};}
    if (!$wg) {$wg = $self->Workgroup;}
    if (!$ip) {$ip=$self->IpAdress; }
    my $debug=' ';
    $debug = " -d ".$self->{DEBUG}.' ' if ($self->{DEBUG});
    # Workgroup
    ($wg ? ($wg = "-W ".$wg." ") : ($wg = ' '));
    # Ip adress of server
    ($ip ? ($ip = "-I ".$ip." ") : ($ip = ' '));
    # Path
    ($dir ? ($dir=' -D "'.$dir.'"') : ($dir= ' '));
    # User / Password
    if (($user)&&($pass)) { $user = '-U '.$user.'%'.$pass.' '; }
    # Don't prompt for password
    elsif ($user && !$pass) {$user = '-U '.$user.' -N ';}
    # Server/share
    my $path=' ';
    if ($host) {$host='//'.$host; $path.=$host; }
    if ($share) {$share='/'.$share;$path.=$share; }
    $path.=' ';
    # Final command
    my $args = $self->{SMBLIENT}.$path.$user.$wg.$ip.
	" -d0 -c '$command' ".$dir;
    return $self->command($args,$command);
  }

#------------------------------------------------------------------------------
# commande
#------------------------------------------------------------------------------
sub commande
  {
    my ($self,$command,$dir, $host, $share, $user, $pass, $wg, $ip) = @_;
    if (!$user) {$user=$self->User;}
    if (!$host) {$host=$self->Host;}    
    if (!$share){$share=$self->Share;}
    if (!$pass) {$pass=$self->Password;}
    if (!$dir) {$dir=$self->{DIR};}
    if (!$wg) {$wg=$self->Workgroup;}
    if (!$ip) {$ip=$self->IpAdress; }
    my $debug=' ';
    $debug = " -d ".$self->{DEBUG}.' ' if ($self->{DEBUG});
    # Ip adress of server
    ($ip ? ($ip = "-I ".$ip." ") : ($ip = ' '));
    # Workgroup
    ($wg ? ($wg = "-W ".$wg." ") : ($wg = ' '));
    # Path
    (($dir) ? ($dir=' -D "'.$dir.'"') : ($dir= ' '));
    # User / Password
    if (($user)&&($pass)) { $user = '-U '.$user.'%'.$pass.' '; }
    # Don't prompt for password
    elsif ($user && !$pass) {$user = '-U '.$user.' -N ';}
    # Server/Share
    my $path=' ';
    if ($host) {$host='//'.$host; $path.=$host; }
    if ($share) {$share='/'.$share;$path.=$share; }
    $path.=' ';
    # Final command
    my $args = $self->{SMBLIENT}.$path.$user.$wg.$ip.
	" -d0 ".$command.$dir;
    return $self->command($args,$command);
  }

#------------------------------------------------------------------------------
# byname
#------------------------------------------------------------------------------
sub byname {(lc $a->{name}) cmp (lc $b->{name})}

#------------------------------------------------------------------------------
# command
#------------------------------------------------------------------------------
sub command
  {
    my ($self,$args,$command)=@_;
    $command.=" >&1";
    if ($self->{"DEBUG"} > 0)
      { print " ==> SmbClientParser::command $args\n"; }
    my $er;
    my $pargs;
    $pargs = $1 if ($args=~/([^;]*)/);
    my @var = `$pargs`;# or die "system $args failed: $?,$!\n";
    my $var=join(' ',@var ) ;
    # Quick return if no answer
    return 1 if (!$var);
    if ($var=~/ERRnoaccess/)   
      {$er="Cmd $command: permission denied";}
    elsif ($var=~/ERRbadfunc/)   
      {$er="Cmd $command: Invalid function.";}
    elsif ($var=~/ERRbadfile/)   
      {$er="Cmd $command: File not found.";}
    elsif ($var=~/ERRbadpath/)   
      {$er="Cmd $command: Directory invalid.";}
    elsif ($var=~/ERRnofids/)   
      {$er="Cmd $command: No file descriptors available";}
    elsif ($var=~/ERRnoaccess/)   
      {$er="Cmd $command: Access denied.";}
    elsif ($var=~/ERRbadfid/)   
      {$er="Cmd $command: Invalid file handle.";}
    elsif ($var=~/ERRbadmcb/)   
      {$er="Cmd $command: Memory control blocks destroyed.";}
    elsif ($var=~/ERRnomem/)   
      {$er="Cmd $command: Insufficient server memory to perform the requested function.";}
    elsif ($var=~/ERRbadmem/)   
      {$er="Cmd $command: Invalid memory block address.";}
    elsif ($var=~/ERRbadenv/)   
      {$er="Cmd $command: Invalid environment.";}
    elsif ($var=~/ERRbadformat/)   
      {$er="Cmd $command: Invalid format.";}
    elsif ($var=~/ERRbadaccess/)   
      {$er="Cmd $command: Invalid open mode.";}
    elsif ($var=~/ERRbaddata/)   
      {$er="Cmd $command: Invalid data.";}
    elsif ($var=~/ERRbaddrive/)   
      {$er="Cmd $command: Invalid drive specified.";}
    elsif ($var=~/ERRremcd/)   
      {$er="Cmd $command: A Delete Directory request attempted to remove the server's current directory.";}
    elsif ($var=~/ERRdiffdevice/)   
      {$er="Cmd $command: Not same device.";}
    elsif ($var=~/ERRnofiles/)   
      {$er="Cmd $command: A File Search command can find no more files matching the specified criteria.";}
    elsif ($var=~/ERRbadshare/)   
      {$er="Cmd $command: The sharing mode specified for an Open conflicts with existing  FIDs  on the file.";}
    elsif ($var=~/ERRlock/)   
      {$er="Cmd $command: A Lock request conflicted with an existing lock or specified an  invalid mode,  or an Unlock requested attempted to remove a lock held by another process.";}
    elsif ($var=~/ERRunsup/)   
      {$er="Cmd $command: The operation is unsupported";}
    elsif ($var=~/ERRnosuchshare/)  
      {$er="Cmd $command: You specified an invalid share name";}
    elsif ($var=~/ERRfilexists/)   
      {$er="Error $command: The file named in a Create Directory, Make New File or Link request already exists.";}
    elsif ($var=~/ERRbadpipe/)   
      {$er="Cmd $command: Pipe invalid.";}
    elsif ($var=~/ERRpipebusy/)   
      {$er="Cmd $command: All instances of the requested pipe are busy.";}
    elsif ($var=~/ERRpipeclosing/)  
      {$er="Cmd $command: Pipe close in progress.";}
    elsif ($var=~/ERRnotconnected/)  
      {$er="Cmd $command: No process on other end of pipe.";}
    elsif ($var=~/ERRmoredata/)   
      {$er="Cmd $command: There is more data to be returned.";}
    elsif ($var=~/ERRinvgroup/)   
      {$er="Cmd $command: Invalid workgroup (try the -W option)";}
    elsif ($var=~/ERRerror/)   
      {$er="Cmd $command: Non-specific error code.";}
    elsif ($var=~/ERRbadpw/) 
      {$er="Cmd $command: Bad password - name/password pair in a Tree Connect or Session Setup are invalid.";}
    elsif ($var=~/ERRbadtype/)  
      {$er="Cmd $command: reserved.";}
    elsif ($var=~/ERRaccess/) 
      {$er="Cmd $command: The requester does not have  the  necessary  access  rights  within  the specified  context for the requested function. The context is defined by the TID or the UID.";}
    elsif ($var=~/ERRinvnid/)   
      {$er="Cmd $command: The tree ID (TID) specified in a command was invalid.";}
    elsif ($var=~/ERRinvnetname/) 
      {$er="Cmd $command: Invalid network name in tree connect.";}
    elsif ($var=~/ERRinvdevice/)  
      {$er="Cmd $command: Invalid device - printer request made to non-printer connection or  non-printer request made to printer connection.";}
    elsif ($var=~/ERRqfull/)  
      {$er="Cmd $command: Print queue full (files) -- returned by open print file.";}
    elsif ($var=~/ERRqtoobig/)
      {$er="Cmd $command: Print queue full -- no space.";}
    elsif ($var=~/ERRqeof/)  
      {$er="Cmd $command: EOF on print queue dump.";}
    elsif ($var=~/ERRinvpfid/)  
      {$er="Cmd $command: Invalid print file FID.";}
    elsif ($var=~/ERRsmbcmd/) 
      {$er="Cmd $command: The server did not recognize the command received.";}
    elsif ($var=~/ERRsrverror/)  
      {$er="Cmd $command: The server encountered an internal error, e.g., system file unavailable.";}
    elsif ($var=~/ERRfilespecs/)  
      {$er="Cmd $command: The file handle (FID) and pathname parameters contained an invalid  combination of values.";}
    elsif ($var=~/ERRreserved/)  
      {$er="Cmd $command: reserved.";}
    elsif ($var=~/ERRbadpermits/)   
      {$er="Cmd $command: The access permissions specified for a file or directory are not a valid combination.  The server cannot set the requested attribute.";}
    elsif ($var=~/ERRreserved/)   
      {$er="Cmd $command: reserved.";}
    elsif ($var=~/ERRsetattrmode/)  
      {$er="Cmd $command: The attribute mode in the Set File Attribute request is invalid.";}
    elsif ($var=~/ERRpaused/)   
      {$er="Cmd $command: Server is paused.";}
    elsif ($var=~/ERRmsgoff/)   
      {$er="Cmd $command: Not receiving messages.";}
    elsif ($var=~/ERRnoroom/)   
      {$er="Cmd $command: No room to buffer message.";}
    elsif ($var=~/ERRrmuns/)  
      {$er="Cmd $command: Too many remote user names.";}
    elsif ($var=~/ERRtimeout/)   
      {$er="Cmd $command: Operation timed out.";}
    elsif ($var=~/ERRnoresource/)   
      { $er="Cmd $command: No resources currently available for request.";}
    elsif ($var=~/ERRtoomanyuids/)  
      {$er="Cmd $command: Too many UIDs active on this session.";}
    elsif ($var=~/ERRbaduid/)   
      {
	$er="Cmd $command: The UID is not known as a valid ID on this session.";
	}
    elsif ($var=~/ERRusempx/)   
      {$er="Cmd $command: Temp unable to support Raw, use MPX mode.";	}
    elsif ($var=~/ERRusestd/)   
      {$er="Cmd $command: Temp unable to support Raw, use standard read/write.";}
    elsif ($var=~/ERRcontmpx/)   
      {$er="Cmd $command: Continue in MPX mode.";}
    elsif ($var=~/ERRreserved/)   
      {$er="Cmd $command: reserved.";}
    elsif ($var=~/ERRreserved/)   
      {$er="Cmd $command: reserved.";}
    elsif ($var=~/ERRnosupport/)   
      {print "Function not supported.";}
    elsif ($var=~/ERRnowrite/)   
      {$er="Cmd $command: Attempt to write on write-protected diskette.";}
    elsif ($var=~/ERRbadunit/)   
      {$er="Cmd $command: Unknown unit.";}
    elsif ($var=~/ERRnotready/)   
      {$er="Cmd $command: Drive not ready.";}
    elsif ($var=~/ERRbadcmd/)   
      {$er="Cmd $command: Unknown command.";}
    elsif ($var=~/ERRdata/)   
      {$er="Cmd $command: Data error (CRC).";}
    elsif ($var=~/ERRbadreq/)   
      {$er="Cmd $command: Bad request structure length.";}
    elsif ($var=~/ERRseek/)   
      {$er="Cmd $command: Seek error.";}
    elsif ($var=~/ERRbadmedia/)  
      {$er="Cmd $command: Unknown media type.";}
    elsif ($var=~/ERRbadsector/)
      {$er="Cmd $command: Sector not found.";}
    elsif ($var=~/ERRnopaper/) 
      {$er="Cmd $command: Printer out of paper.";}
    elsif ($var=~/ERRwrite/) 
      {$er="Cmd $command: Write fault.";}
    elsif ($var=~/ERRread/) 
      {$er="Cmd $command: Read fault.";}
    elsif ($var=~/ERRgeneral/)
      {$er="Cmd $command: General failure.";}
    elsif ($var=~/ERRbadshare/) 
      {$er="Cmd $command: An open conflicts with an existing open.";}
    elsif ($var=~/ERRlock/) 
      {$er="Cmd $command: A Lock request conflicted with an existing lock or specified an invalid mode, or an Unlock requested attempted to remove a lock held by another process.";}
    elsif ($var=~/ERRwrongdisk/) 
      {$er="Cmd $command: The wrong disk was found in a drive.";}
    elsif ($var=~/ERRFCBUnavail/)  
      {$er="Cmd $command: No FCBs are available to process request.";}
    elsif ($var=~/ERRsharebufexc/)
      {$er="Cmd $command: A sharing buffer has been exceeded.";}
    elsif ($var=~/ERRDOS - 183 renaming files/)
      {$er="Cmd $command: File target already exist.";}
#    elsif ($var=~/ERR/) {$er="Cmd $command: reserved.";}
    elsif ($var=~/(NT_STATUS_[^ \n]*)/ && $1 ne 'NT_STATUS_OK') {
      $er = $1; }
    $self->{LAST_REP} = \@var;
    $self->{LAST_ERR} = $er if ($er);
  return (defined($er) ? undef : 1);
  }

#------------------------------------------------------------------------------
# POD DOCUMENTATION
#------------------------------------------------------------------------------

=head1 NAME

Filesys::SmbClientParser - Perl client to reach Samba ressources with smbclient

=head1 SYNOPSIS

  use Filesys::SmbClientParser;
  my $smb = new Filesys::SmbClientParser
  (undef,
   (
    user     => 'Administrateur',
    password => 'password'
   ));
  # Or like -A parameters:
  $smb->Auth("/home/alian/.smbpasswd");

  
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


See test.pl file for others examples.

=head1 DESCRIPTION

SmbClientParser work with output of bin smbclient, so it doesn't work
on win platform. (but query of win platform work of course)

A best method is work with a samba shared librarie and xs language,
but on Nov.2000 (Samba version prior to 2.0.8) there is no public
interface and shared library defined in Samba projet.

Request has been submit and accepted on Samba-technical mailing list,
so I've build another module called Filesys-SmbClient that use features
of this library. (libsmbclient.so)

For Samba client prior to 2.0.8, use this module !

SmbClientParser is adapted from SMB.pm make by Remco van Mook
mook@cs.utwente.nl on smb2www project.

=head1 INTERFACE

=head2 Objects methods

=over

=item new([$path_of_smbclient], [%param])

Create a new FileSys::SmbClientParser instance. Search bin smbclient,
and fail if it can't find it in /usr/bin, /usr/local/bin, /opt/bin or
/usr/local/samba/bin/.
If it's on another directory, use parameter $path_of_smbclient.

%param is a hash with key user,host,password,workgroup,ipadress,share

=item Host([$hostname])

Set or get the remote host to be used to $hostname.

=item User([$username])

Set or get the username to be used to $username.

=item Share([$sharename])

Set or get the share to be used on the remote host to $sharename.

=item Password([$password])

Set or get the password to be used

=item Workgroup([$wg])

Set or get the workgroup to be used. (See -W switch in smbclient man page)

=item IpAdress([$ip])

Set or get the IP adress of the server to contact (See -I switch in smbclient 
man page)

=item Debug([$debug])

Set or get the debug verbosity

    0 = no output
    1+ = more output

=item Auth($auth_file)

Use the file $auth_file for username and password.
This uses User and Password instead of -A to be backwards
compatible.

=back

=head2 Network methods

=over

=item GetGroups([$host],[$user],[$pass],[$wg],[$ip])

If no parameters is given, field will be used.

Return an array with sorted workgroup listing

Syntax: @output = $smb->GetGroups

array contains hashes; keys: name, master

=item GetShr([$host],[$user],[$pass],[$wg],[$ip])

If no parameters is given, field will be used.

Return an array with sorted share listing

Syntax: @output = $smb->GetShr

array contains hashes; keys: name, type, comment

=item GetHosts([$host],[$user],[$pass],[$wg],[$ip])

Return an array with sorted host listing

Syntax: @output = $smb->GetHosts

array contains hashes; keys: name, comment

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

=back

=head2 Operations

=over

=item cd [$dir] [$host ,$user, $pass, $wg, $ip]


cd [directory name]
If "directory name" is specified, the current working directory on the server
will be changed to the directory specified. This operation will fail if for
any reason the specified directory is inaccessible. Return list.

If no directory name is specified, the current working directory on the server
will be reported.

=item dir [$dir] [$host ,$user, $pass, $wg, $ip]

Return an array with sorted dir and filelisting

Syntax: @output = $smb->dir (host,share,dir,user,pass)

Array contains hashes; keys: name, attr, size, date

=item mkdir($masq, [$dir, $host ,$user, $pass, $wg, $ip])

mkdir <mask>
Create a new directory on the server (user access privileges
permitting) with the specified name.

=item rmdir($masq, [$dir, $host ,$user, $pass, $wg, $ip])

Remove the specified directory (user access privileges
permitting) from the server.

=item get($file, [$target], [$dir, $host ,$user, $pass, $wg, $ip])

Gets the file $file, using $user and $pass, to $target on courant SMB
server and return the error code.
If $target is unspecified, courant directory will be used
For use STDOUT, set target to '-'.

Syntax: $smb->get ($file,$target,$dir)

=item del($mask, [$dir, $host ,$user, $pass, $wg, $ip])

del <mask>
The client will request that the server attempt to delete
all files matching "mask" from the current working directory
on the server

=item rename($source, $target, [$dir, $host ,$user, $pass, $wg, $ip])

rename source target
The file matched by mask will be moved to target.  These names
can be in differnet directories.  It returns a return value.

=item pwd()

Returns the present working directory on the remote system.  If
there is an error it returns undef. If you are on smb://jupiter/doc/mysql/,
pwd return \doc\mysql\.

=item du([$path, $unit)

If no path is given current directory is used.

Unit can be in [kbsmg].

=over

=item b

Posix blocks

=item k

1Kbyte blocks

=item s

Samba blocks

=item m

1Mbyte blocks

=item g

1Gbyte blocks

=back

If no unit given, k is used (1kb bloc)

In scalar context, return the total size in units for files in 
current directory.

In array context, return a list with total size in units for files in 
directory, size left in partition of share, block size used in bytes,
total size of partition of share.

=item mget($file,[$recurse])

Gets file(s) $file on current SMB server,directory and return
the error code. If multiple file, push an array ref as first parameter
or pattern * or file separated by space

Syntax:

  $smb->mget ('file'); #or
  $smb->mget (join(' ',@file); #or
  $smb->mget (\@file); #or
  $smb->mget ("*",1);

=item put$($orig,[$file],[$dir, $host ,$user, $pass, $wg, $ip])

Puts the file $orig to $file, using $user and $pass on courant SMB
server and return the error code. If no $file specified, use same 
name on local filesystem.
If $orig is unspecified, STDIN is used (-).

Syntax: $smb->PutFile ($host,$share,$file,$user,$pass,$orig)

=item mput($file,[$recurse])

Puts file(s) $file on current SMB server,directory and return
the error code. If multiple file, push an array ref as first parameter
or pattern * or file separated by space

Syntax:

  $smb->mput ('file'); #or
  $smb->mput (join(' ',@file); #or
  $smb->mput (\@file); #or
  $smb->mput ("*",1);

=back

=head2 Archives methods

=over

=item tar($command, $target, [$dir, $host ,$user, $pass, $wg, $ip])

Execute TAR commande on //$host/$share/$dir, using $user and $pass
and return the error code. $target is name of tar file that will be used

Syntax: $smb->tar ($command,'/tmp/myar.tar') where command 
in ('x','c',...) 
See smbclient man page

=back

=head2 Error methods

All methods return undef on error and set err in $smb->err.

=over

=item err

Return last text error that smbclient found

=item LastResponse

Return last buffer return by smbclient

=back

=head2 Private methods

=over

=item byname

sort an array of hashes by $_->{name} (for GetSMBDir et al)

=item operation(...)

=item command($args,$command)

=back

=head1 TODO

Write a wrapper for ActiveState release on win32

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=head1 SEE ALSO

smbclient(1) man pages.

=cut
