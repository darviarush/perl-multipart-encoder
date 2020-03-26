package Multipart::Encoder;
use 5.008001;
use strict;
use warnings;

my $CRLF = "\r\n";

#use Carp; $SIG{__DIE__} = sub { die Carp::confess @_ };

sub new {
	my ($cls) = shift;
	bless {
		boundary => 'xYzZY',
        buffer_size => 1024 * 2,
		content => [@_],
	}, ref $cls || $cls
}

sub boundary {
	my $self = shift;
	if(@_) {
		$self->{boundary} = shift;
		$self
	}
	else {
		$self->{boundary}
	}
}

sub buffer_size {
	my $self = shift;
	if(@_) {
		$self->{buffer_size} = shift;
		$self
	}
	else {
		$self->{buffer_size}
	}
}

sub content_type { 'multipart/form-data' }

sub as_string {
	my ($self) = @_;
	my @result;
	$self->_gen(sub { push @result, @_ });
	return join "", @result;
}

sub to {
	my ($self, $to) = @_;

	my $f;
	if(UNIVERSAL::can($to, "write")) {
		$f = $to;
	} else {
		open $f, ">", $to or die "Not open $to. $!";
	}

	$self->_gen(sub {
		for my $part (@_) {
			$f->write($part);
		}
	});

	if(!UNIVERSAL::can($to, "write")) {
		close $f;
	}

	$self
}

sub _magic {
	require "File/LibMagic.pm";
	my $magic = File::LibMagic->new;
	no warnings 'redefine';
	*_magic = sub { return $magic };
	$magic
}

sub _basefile {
	my ($path) = @_;
	return $path =~ m![^/]+$!? "$&": die "Not file name in path `$path`";
}

sub _gen {
    my ($self, $gen) = @_;

	my $i = 0;
	my $key;
    for my $param (@{$self->{content}}) {

		if($i++ % 2 == 0) {
			$key = $param;
			next;
		}

		$param = ref $param eq "HASH"? [%$param]: ref $param eq "ARRAY"? $param: [ _ => $param ];

		my $j = 0;
		my $k;
		my $value;
		my $is_disp;
		my $is_type;
		my $fh;
		my $size;

		my $message = join '',
			("--", $self->{boundary}, $CRLF),
			(map {
				$j++ % 2==0? do { $k = $_; () }:
				$k eq "_"? do { $value = $_; () }:
				do {
					$is_disp = 1 if $k =~ /^Content-Disposition\z/i;
					$is_type = 1 if $k eq /^Content-Type\z/i;
					($k, ": ", $_, $CRLF)
				}
			} @{$param}),
			ref $value eq "SCALAR"? do {
				open $fh, "<", $$value or die "Not open file `$$value`: $!";
				$size = read $fh, my $buf, $self->{buffer_size};

				if(!defined $size) {
					close($fh);
					die "Not read from file `$$value`: $!";
				}

				(
					$is_disp? (): ('Content-Disposition: form-data; name="', $key, '"; filename="', _basefile($$value), '"', $CRLF),
					$is_type? (): ("Content-Type: ", _magic()->info_from_string($buf)->{mime_with_encoding}, $CRLF),
					$CRLF,
					$buf,
					$size == $self->{buffer_size}? (): do { close $fh; undef $fh; $CRLF },
				)
			}: (
				'Content-Disposition: form-data; name="', $key, '"', $CRLF,
				$CRLF,
				$value, $CRLF
			);

		$gen->($message);

		next if !defined $fh;

		while($size == $self->{buffer_size}) {
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

=head1 NAME

Mime::Multipart - encoder for mime-type C<multipart/form-data>

=head1 VERSION

0.0.1

=head1 SYNOPSIS

    use Multipart;

	my $multipart = Multipart->new(
		x=>1,
		file_name => \"file.txt",
		y=>[
			"Content-Type" => "text/json",
			name => 'my-name',
			filename => 'my-filename',
			_ => '{"count": 666}',
			'Any-Header' => 123,
		],
		z => {
			_ => \'path/to/file.zip',
			'Any-Header' => 123,
		}
	)->buffer_size(2048)->boundary("xYzZY");

	my $str = $multipart->as_string;

	$multipart->to("path/to/file.form-data");

	$multipart->to(\*STDOUT);

	$multipart->to($socket);

=head1 DESCRIPTION

Сериалайзер в C<multipart/form-data>.

=head1 LICENSE

Copyright (C) Yaroslav O. Kosmina.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Yaroslav O. Kosmina E<lt>kosmina.yaroslav@220-volt.ruE<gt>

=cut
