use Ddt;
use Ddt::Distribution;

unit module Ddt::Plugins::Watch;

#| Watch lib/, bin/ & t/ for changes respecting .gitignore and execute given cmd
multi MAIN("watch", 
    *@cmd #= A shell command to execute
    ) is export {
    my $ddt = Ddt::Distribution.new: TOPDIR;
    my Proc::Async $proc .= new: @cmd;
    $proc.start;
    $ddt.watch.act: {
        with $proc { .kill; say "Restarting @cmd.join(" ")"};
        $proc = Proc::Async.new: @cmd;
        $proc.start;
    }
    loop {}
}

