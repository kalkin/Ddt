use License::Software:ver<0.3.*>;
unit class Ddt::License does License::Software::Abstract;

submethod aliases returns Array[Str]  { Array[Str].new }
method files returns Hash:D { Hash.new }
method header returns Str:D  { $!name && "This piece of software is released under license '$!name'."  }
#method full-text returns Str:D  { "self.header()\nFor details, contact the author." }
method full-text returns Str:D  { ... }
has Str $.name;
method !set-name($!name) { self }
multi method new(Ddt::License: Str:D $holder-name, :$name!) {
    self.new($holder-name, |%)!set-name($name)
}
multi method new(Ddt::License: :$name!) {
    self.new(|%)!set-name($name)
}
method note returns Str  { '' }
method short-name returns Str  { $!name }
method spdx returns Str  { $!name }
submethod url returns Str  { '' }
