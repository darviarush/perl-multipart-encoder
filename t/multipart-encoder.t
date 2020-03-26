use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;

use_ok "Multipart::Encoder";

my $FILE1 = "/tmp/multipart-encoder/t/file.txt";
my $C1 = "123\n456";
my $FILE2 = "/tmp/multipart-encoder/t/file.zip";
my $C2 = "\x1f\x8b\x08\x00\x2b\x5f\x5f\x5e\x00\x03\x33\x34\x32\xe6\x02\x00\x08\xfd\x82\x5a\x04\x00\x00\x00";

my ($NAME1) = $FILE1 =~ /([^\/]+)$/;
my ($NAME2) = $FILE2 =~ /([^\/]+)$/;

my $MULTIPART_FORM_DATA = qq{--xYzZY\r
Content-Disposition: form-data; name="x"\r
\r
1\r
--xYzZY\r
Content-Disposition: form-data; name="file with space"; filename="$NAME1"\r
Content-Type: text/plain; charset=us-ascii\r
\r
$C1\r
--xYzZY\r
Content-Type: text/json\r
name: my-name\r
filename: my-filename\r
Any-Header: 123\r
Content-Disposition: form-data; name="y"\r
\r
{"count": 666}\r
--xYzZY\r
Any-Header: 567\r
Content-Disposition: form-data; name="z"; filename="$NAME2"\r
Content-Type: application/gzip; charset=binary\r
\r
$C2\r
--xYzZY--\r
};



END { unlink $FILE1; unlink $FILE2; }
my $f;
mkdir $` while $FILE1 =~ /\//g;
open $f, ">", $FILE1 and do { print $f $C1; close $f }; 
open $f, ">", $FILE2 and do { print $f $C2; close $f };


my $multipart = Multipart::Encoder->new(
	x=>1, 
	"file with space" => \$FILE1, 
	y=>[
		"Content-Type" => "text/json", 
		name => 'my-name',
		filename => 'my-filename', 
		_ => '{"count": 666}',
		'Any-Header' => 123,
	],
	z => {
		_ => \$FILE2,
		'Any-Header' => 567,
	}
)->buffer_size(2048)->boundary("xYzZY");


subtest as_string => sub {
    plan tests => 1;

	my $str = $multipart->as_string;
	is $str, $MULTIPART_FORM_DATA, "Ответ совпадает";
};

subtest content_type => sub {
    plan tests => 1;

	is $multipart->content_type, "multipart/form-data";
};

subtest to => sub {
    plan tests => 2;

	my $f = "/tmp/multipart-encoder/t/x.txt";
	$multipart->to($f);

	open my $ff, "<", $f;
	is $multipart->as_string, join "", <$ff>;
	close $ff;

	open my $ff, ">", $f or die $!; $multipart->to($ff); close $ff;

	open my $ff, "<", $f;
	is $multipart->as_string, join "", <$ff>;
	close $ff;
};
