package Multipart::Encoder;
use 5.008001;
use strict;
use warnings;

our $VERSION = v0.0.2;

my $CRLF = "\r\n";

sub new {
    my ($cls) = shift;
    bless {
        boundary    => 'xYzZY',
        buffer_size => 1024 * 2,
        content     => [@_],
      },
      ref $cls || $cls;
}

sub boundary {
    my $self = shift;
    if (@_) {
        $self->{boundary} = shift;
        $self;
    }
    else {
        $self->{boundary};
    }
}

sub buffer_size {
    my $self = shift;
    if (@_) {
        $self->{buffer_size} = shift;
        $self;
    }
    else {
        $self->{buffer_size};
    }
}

sub content_type { 'multipart/form-data' }

sub as_string {
    my ($self) = @_;
    my @result;
    $self->_gen( sub { push @result, @_ } );
    return join "", @result;
}

sub to {
    my ( $self, $to ) = @_;

    my $f;
    if ( UNIVERSAL::can( $to, "write" ) ) {
        $f = $to;
    }
    else {
        open $f, ">", $to or die "Not open file `$to`. $!";
    }

    $self->_gen(sub { $f->write($_) for @_ });

    close $f if !UNIVERSAL::can( $to, "write" );

    $self;
}

sub _magic {
    require "File/LibMagic.pm";
    my $magic = File::LibMagic->new;
    no warnings 'redefine';
    *_magic = sub { return $magic };
    $magic;
}

sub _basefile {
    my ($path) = @_;
    $path =~ m![^/]*\z!;
    return $&;
}

sub _gen {
    my ( $self, $gen ) = @_;

    my $i = 0;
    my $key;
    for my $param ( @{ $self->{content} } ) {

        if ( $i++ % 2 == 0 ) {
            $key = $param;
            next;
        }

        $param =
            ref $param eq "HASH"  ? [%$param]
          : ref $param eq "ARRAY" ? $param
          :                         [ _ => $param ];

        my $j = 0;
        my $k;
        my $value;
        my $use_name;
        my $use_filename;
        my $is_disp;
        my $is_type;
        my $fh;
        my $size;

        my $message = join '', ( "--", $self->{boundary}, $CRLF ), (
            map {
                    $j++ % 2 == 0    ? do { $k            = $_; () }
                  : $k eq "_"        ? do { $value        = $_; () }
                  : $k eq "name"     ? do { $use_name     = $_; () }
                  : $k eq "filename" ? do { $use_filename = $_; () }
                  : do {
                    $is_disp = 1 if $k =~ /^Content-Disposition\z/i;
                    $is_type = 1 if $k =~ /^Content-Type\z/i;
                    ( $k, ": ", $_, $CRLF );
                }
            } @{$param}
          ),
          ref $value eq "SCALAR"? do {
            open $fh, "<", $$value or die "Not open file `$$value`: $!";
            $size = read $fh, my $buf, $self->{buffer_size};

            (
                $is_disp ? (): (
                    'Content-Disposition: form-data; name="', $use_name // $key,
                    '"; filename="', $use_filename // _basefile($$value), '"',
                    $CRLF
                ),
                $is_type ? (): (
                    "Content-Type: ", _magic()->info_from_string($buf)->{mime_with_encoding},
                    $CRLF
                ),
                $CRLF, $buf,
                $size == $self->{buffer_size} ? (): do { close $fh; undef $fh; $CRLF },
            );
          }: (
            'Content-Disposition: form-data; name="', $use_name // $key, '"',
            defined($use_filename) ? ( '; filename="', $use_filename, '"' ): (),
            $CRLF,
            $CRLF,
            $value,
            $CRLF
          );

        $gen->($message);

        next if !defined $fh;

        while ( $size == $self->{buffer_size} ) {
            $size = read $fh, my $buf, $self->{buffer_size};
            $gen->($buf);
        }

        close $fh;
        $gen->($CRLF);
    }

    $gen->("--$self->{boundary}--$CRLF");
    return;
}

1;
__END__

=encoding utf-8

# NAME

Multipart::Encoder - encoder for mime-type `multipart/form-data`.

# VERSION

v0.0.2

# SINOPSIS

`@@/tmp/file.txt`

```txt
Simple text.

`gzip < /tmp/file.txt > /tmp/file.gz`;
$?	#  0

use Multipart::Encoder;

my $multipart = Multipart::Encoder->new(
	x=>1,
	file_name => \"/tmp/file.txt",
	y=>[
		"Content-Type" => "text/json",
		name => 'my-name',
		filename => 'my-filename',
		_ => '{"count": 666}',
		'Any-Header' => 123,
	],
	z => {
		_ => \'/tmp/file.gz',
		'Any-Header' => 123,
	}
)->buffer_size(2048)->boundary("xYzZY");

my $str = $multipart->as_string;

utf8::is_utf8($str)			## ""

$str 						#~ \r\n--xYzZY--\r\n\z

$multipart->to("/tmp/file.form-data");

open my $f, "<", "/tmp/file.form-data"; binmode $f; read $f, my $buf, -s $f; close $f;

utf8::is_utf8($buf)			## ""

$buf						## $str

$multipart->to(\*STDOUT);	##>> $str

```

# DESCRIPTION

The encoder in 'multipart/form-data' is not represented in perl libraries. It is only used as part of other libraries, for example, `HTTP::Tiny::Multipart`.

But there is no such library for `AnyEvent::HTTP`.

The only module `HTTP::Body::Builder::MultiPart` does not allow adding a file as a string to a **multipart**.

# INSTALL

`$ cpm install -g Multipart::Encoder`

# SUBROUTINES/METHODS

## new

Constructor.


```perl
my $multipart = Multipart::Encoder->new;
my $multipart2 = $multipart->new;
$multipart2	##!= $multipart

ref Multipart::Encoder::new(0)	# 0

```

**Return** new object.

Arguments is a params for serialize to multipart-format.


```perl
Multipart::Encoder->new(x=>123)->as_string    #~ 123	

```

## content_type


```perl
$multipart->content_type	# multipart/form-data

```

## buffer_size

Set or get buffer size. Buffer using for write to file.


```perl
$multipart->buffer_size(1024)->buffer_size		# 1024

```

Default buffer size:


```perl
Multipart::Encoder->new->buffer_size			# 2048

```

## boundary

Boundary is a separator before params in multipart-data.


```perl
$multipart->boundary("XYZooo")->boundary		# XYZooo

```

Default boundary:


```perl
Multipart::Encoder->new->boundary				# xYzZY

```

## as_string

Serialize params to a string.


```perl
Multipart::Encoder->new(x=>123, y=>456)->as_string   #~ 123

```

## to

Serialize params and print it in multipart format to a file use buffer with `buffer_size`.
Argument for `to`  must by path or filehandle.


```perl
$multipart->to("/tmp/file.form-data");

open my $f, ">", "/tmp/file.form-data"; binmode $f;
$multipart->to($f);
close $f;

```

If file not open raise the die.


```perl
$multipart->to("/")		#@ ~ Not open file `/`. Is a directory

```

# PARAMS

Param types is file and string.

## String param type


```perl
Multipart::Encoder->new(x=>"Simple string")->as_string	#~ Simple string

```

With headers:


```perl
my $str = Multipart::Encoder->new(
	x => {
		_ => "Simple string",
		header => 123,
	},
)->as_string;

$str #~ Simple string
$str #~ header: 123

```

Header **Content-Disposition** added automically.


```perl
Multipart::Encoder->new(x=>"Simple string")->as_string	#~ Content-Disposition: form-data; name="x"

```

Name in **Content-Disposition** set as key, or name-header:


```perl
my $str = Multipart::Encoder->new(
	x => {
		_ => "Simple string",
		name => "xyz",
	},
)->as_string;

$str #~ Content-Disposition: form-data; name="xyz"

```

If need filename in **Content-Disposition**, add it:


```perl
my $str = Multipart::Encoder->new(
	0 => {
		_ => "Simple string",
		filename => "xyz.tgz",
	},
)->as_string;

$str #~ Content-Disposition: form-data; name="0"; filename="xyz.tgz"

```

If **Content-Disposition** is, then it use once.


```perl
my $str = Multipart::Encoder->new(
	x => {
		_ => "Simple string",
		'content-disposition' => "form-data; name=\"z\"; filename=\"xyz\"",
	},
)->as_string;

$str #~ content-disposition: form-data; name="z"; filename="xyz"

```

## File param type

Header **Content-Disposition** added automically.


```perl
open my $f, ">/tmp/0"; close $f;

Multipart::Encoder->new(x=>\"/tmp/0")->as_string	#~ Content-Disposition: form-data; name="x"; filename="0"

```

Header **Content-Type** added automically.


```perl
Multipart::Encoder->new(x=>\"/tmp/file.gz")->as_string	#~ Content-Type: application/x-gzip; charset=binary

```

But if it is, then used once.


```perl
my $str = Multipart::Encoder->new(
	x => [
		_ => \"/tmp/file.gz",
		'content-type' => 'text/plain',
	]
)->as_string;

$str #~ content-type: text/plain
$str #!~ Content-Type

```

Name in **Content-Disposition** set as key, or name-header:


```perl
my $str = Multipart::Encoder->new(
	x => {
		_ => \"/tmp/file.txt",
		name => "xyz",
	},
)->as_string;

$str #~ Content-Disposition: form-data; name="xyz"; filename="file.txt"

```

If need filename in **Content-Disposition**, add it:


```perl
my $str = Multipart::Encoder->new(
	0 => {
		_ => \"/tmp/file.txt",
		filename => "xyz.tgz",
	},
)->as_string;

$str #~ Content-Disposition: form-data; name="0"; filename="xyz.tgz"

```

If **Content-Disposition** is, then it use once.


```perl
my $str = Multipart::Encoder->new(
	x => [
		_ => \"/tmp/file.txt",
		'content-disposition' => "form-data; name=\"z\"; filename=\"xyz\"",
	],
)->as_string;

$str #~ content-disposition: form-data; name="z"; filename="xyz"

```

Big file.


```perl
open my $f, ">", "/tmp/bigfile"; binmode $f; print $f 0 x 65534; close $f;
Multipart::Encoder->new(x=>\"/tmp/bigfile")->as_string	#~ \n0{65534}\r

```

Raise if not open file.


```perl
Multipart::Encoder->new(x=>\"/tmp/NnKkMm346485923")->as_string #@ ~ Not open file `/tmp/NnKkMm346485923`: No such file or directory 


```

# SEE ALSO

* [HTTP::Tiny::Multipart]
* [HTTP::Body::Builder::MultiPart]

# LICENSE

Copyright (C) Yaroslav O. Kosmina.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

# AUTHOR

Yaroslav O. Kosmina <darviarush@mail.ru>
