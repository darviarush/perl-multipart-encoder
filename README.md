# NAME
## Меню
1. [NAME](#NAME)
2. [VERSION](#VERSION)
3. [SINOPSIS](#SINOPSIS)
4. [DESCRIPTION](#DESCRIPTION)
5. [INSTALL](#INSTALL)
6. [SUBROUTINES/METHODS](#SUBROUTINES/METHODS)
7. [new](#new)
8. [content_type](#content_type)
9. [buffer_size](#buffer_size)
10. [boundary](#boundary)
11. [as_string](#as_string)
12. [to](#to)
13. [PARAMS](#PARAMS)
14. [String param type](#String param type)
15. [File param type](#File param type)
16. [SEE ALSO](#SEE ALSO)
17. [LICENSE](#LICENSE)
18. [AUTHOR](#AUTHOR)
19. [Документация](#Документация)

Multipart::Encoder - encoder for mime-type `multipart/form-data`.

# VERSION

v0.0.3

# SINOPSIS


```perl
`echo "Simple text." > /tmp/file.txt`;
$?	#  0
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
my $multipart1 = Multipart::Encoder->new;
my $multipart2 = $multipart1->new;
$multipart2	##!= $multipart1

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

* `HTTP::Tiny::Multipart`
* `HTTP::Body::Builder::MultiPart`

# LICENSE

Copyright (C) Yaroslav O. Kosmina.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

# AUTHOR

Yaroslav O. Kosmina <darviarush@mail.ru>


## Документация

1. [NAME](.miu/mark/multipart-encoder.markdown)
