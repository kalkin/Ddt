#`(
This file is heavely based on JSON::Pretty. The only difference is, that it
strips empty strings and sorts the object keys alphabetically. The sorting makes
sure we get an identical JSON String each time.
)
unit module Ddt::JSON;

my $s = 2;
proto to-sorted-json($, :$indent = 0, :$first = 0) is export {*}

multi to-sorted-json(Real:D $d, :$indent = 0, :$first = 0) { (' ' x $first) ~ ~$d }
multi to-sorted-json(Bool:D $d, :$indent = 0, :$first = 0) { (' ' x $first) ~ ($d ?? 'true' !! 'false') }
multi to-sorted-json(Str:D $d, :$indent = 0, :$first = 0) {
    (' ' x $first) ~ '"'
    ~ $d.trans(['"', '\\', "\b", "\f", "\n", "\r", "\t"]
            => ['\"', '\\\\', '\b', '\f', '\n', '\r', '\t'])\
            .subst(/<-[\c32..\c126]>/, { ord(~$_).fmt('\u%04x') }, :g)
    ~ '"'
}
multi to-sorted-json(Positional:D $d, :$indent = 0, :$first = 0) {
    return (' ' x $first) ~ "\["
            ~ ($d ?? $d.sort.grep(* !~~ "").map({ "\n" ~ to-sorted-json($_, :indent($indent + $s), :first($indent + $s)) }).join(",") ~ "\n" ~ (' ' x $indent) !! ' ')
            ~ ']';
}
multi to-sorted-json(Associative:D $d, :$indent = 0, :$first = 0) {
    return (' ' x $first) ~ "\{"
            ~ ($d ?? $d.sort.map({ "\n" ~ to-sorted-json(.key, :first($indent + $s)) ~ ' : ' ~ to-sorted-json(.value, :indent($indent + $s)) }).join(",") ~ "\n" ~ (' ' x $indent) !! ' ')
            ~ '}';
}

multi to-sorted-json(Mu:U $, :$indent = 0, :$first = 0) { 'null' }
multi to-sorted-json(Mu:D $s, :$indent = 0, :$first = 0) {
    die "Can't serialize an object of type " ~ $s.WHAT.raku
}
