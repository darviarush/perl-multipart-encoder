# NAME

Mime::Multipart - encoder for mime-type `multipart/form-data`

# VERSION

0.0.1

# SYNOPSIS

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

# DESCRIPTION

����������� � `multipart/form-data`.

# LICENSE

Copyright (C) Yaroslav O. Kosmina.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Yaroslav O. Kosmina <darviarush@mail.ru>
