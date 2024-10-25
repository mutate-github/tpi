#!/usr/bin/perl
use Mail::Sender;
use Sys::Hostname;

$host=hostname;
$smtp='mail.nomadlife.kz';
$port='587';
$auth='NTLM';
$authdomain='nomadlife.local';
$authid='oracle';
$authpwd='ASzxqw12';
$from='oracle@nomadlife.kz';

# test protocol of mail server:
# @protocols = $sender->QueryAuthProtocols('mail.nomadlife.kz');
# print @protocols;
# perl -MMail::Sender -e "Mail::Sender->printAuthProtocols('mail.nomadlife.kz')"

foreach $arg (@ARGV){
    $shift_count++;
    if($arg eq "-s"){
      $mode="Subject";
      next;
    }
    ($mode,$to)=("",$to . "$arg, ") if $arg =~ /\@/;
    $subject.="$arg " if $mode eq "Subject";

    if($arg eq "-a"){
      $mode="Attach";
      next;
      $file.="$arg ";
    }
    $file.="$arg" if $mode eq "Attach";
}


for (1..$shift_count){
  shift;
}
while(<>){
  $msg.=$_;
}
$to=~s/, $//;


#send $msg to telegram bot
#$BASEDIR=`dirname $0`;
#chop($BASEDIR);
#$TLGRM_CMD=`$BASEDIR/iniget.sh mon.ini.$CLIENT telegram cmd`;
#$TLGRM_CHT=`$BASEDIR/iniget.sh mon.ini.$CLIENT telegram chat_id`;
#chop($TLGRM_CMD);
#chop($TLGRM_CHT);
#chop($msg);
#$RC="$TLGRM_CMD mark0 $TLGRM_CHT \"sender: $from\n\\`$msg\\`\"";
#$RC=system("$TLGRM_CMD mark0 $TLGRM_CHT \"sender: $from\n\\`$msg\\`\"");
##print $RC;



ref ($sender = new Mail::Sender(
{from => "$from",
 port => "$port",
 smtp => "$smtp"}
)) or die "$Mail::Sender::Error\n";
if ($file)
{
(ref ($sender->MailFile({to => "$to",
                        from => "$from",
                        subject => "$subject - $host",
#        ctype => 'text/plain; charset=UTF-8',
#        ctype => 'text/html; charset=us-ascii',
#        ctype => 'text/plain; charset=Windows-1251',
#        ctype => 'text/plain; charset=iso-8859-5',
#        encoding => "quoted-printable",
        auth => "$auth",
#  auth_encoded => 1,
        authdomain => "$authdomain",
        authid => "$authid",
        authpwd => "$authpwd",
        msg => "$msg",
        file => $file}))
and print "Mail sent OK.\n" ) or die "$Mail::Sender::Error\n";
}
else
{
(ref ($sender->MailMsg({to => "$to",
                        from => "$from",
                        subject => "$subject - $host",
 ctype => 'text/plain; charset=UTF-8',
# ctype => 'text/html; charset=us-ascii',
#  ctype => 'text/plain; charset=Windows-1251',
# ctype => 'text/plain; charset=iso-8859-5',
  encoding => "quoted-printable",
  auth => "$auth",
#  auth_encoded => 1,
  authdomain => "$authdomain",
  authid => "$authid",
  authpwd => "$authpwd",
  msg => "$msg"}))
and print "Mail sent OK.\n" ) or die "$Mail::Sender::Error\n";
# The SMTP authentication protocol to use to login to the server currently the only ones supported are LOGIN, PLAIN, CRAM-MD5 and NTLM. Some protocols have module dependencies. CRAM-MD5 depends on Digest::HMAC_MD5 and NTLM on Auth                                                                                                                                                       en::NTLM.
}

