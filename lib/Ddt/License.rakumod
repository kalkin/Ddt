use License::Software:ver<0.3.*>;
unit class Ddt::License does License::Software::Abstract;

submethod aliases returns Array[Str]  { Array[Str].new }
method files returns Hash:D { Hash.new }
method header returns Str:D  { "This piece of software is released under licence '$!name'."  }
method full-text returns Str:D  { "self.header()\nFor details, contact the author." }
has Str $.name = 'DEMO';
method note returns Str:D  { '' }
method short-name returns Str:D  { $!name }
method spdx returns Str:D  { $!name }
submethod url returns Str:D  { '' }