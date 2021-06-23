use Ddt;
use Ddt::Distribution;
unit module Ddt::Plugins::Test;

#| Run distribution tests
multi MAIN("test",
            Str  :$state,       #= Control prove's persistent state
            Bool :$timer,       #= Print elapsed time after each test
            Bool :v(:$verbose), #= Print all test lines
            Bool :c(:$color),   #= Colored test output (default when terminal)
            Bool :C(:$continues), # Run tests on file change
                 *@tests        #= Files or directories
           ) is export
{
    temp $*CWD = TOPDIR;
    if @tests ~~ Empty {
        @tests.push: TOPDIR.child(<t>) if TOPDIR.child(<t>) ~~ :e & :d;
        @tests.push: TOPDIR.child(<xt>) if TOPDIR.child(<xt>) ~~ :e & :d;
    }
    my Str @args = [];
    my $ddt = Ddt::Distribution.new: TOPDIR;
    @args.push: '--timer' if $timer.defined;
    @args.push: '-c' if $color.defined || $*IN.t;
    @args.push: '-v' if $verbose.defined;
    @args.push: "--state=$state" if $state.defined;

    if $continues {
        my Proc::Async $proc .= new: 'prove', @args, '--exec', 'raku -I.', @tests;
        $proc.start;

        $ddt.watch.act: {
            with $proc { .kill(9) }
            say "Restarting tests";
            $proc = Proc::Async.new: 'prove', @args, '--exec', 'raku -I.', @tests;
            $proc.start;
        };
        without $proc { $proc = Proc::Async.new: 'prove', @args, '--exec', 'raku -I.', @tests;}
        loop { FIRST { say "Waiting for changes" } }
    } else {
        run 'prove', @args, '--exec', 'raku -I.', @tests;
    }
}
