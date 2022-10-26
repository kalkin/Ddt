unit module Ddt::JSON;
use JSON::Fast;

sub to-sorted-json($content) is export {
  to-json $content, :pretty, :sorted-keys;
}

