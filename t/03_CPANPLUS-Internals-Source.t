### make sure we can find our conf.pl file
BEGIN { 
    use FindBin; 
    require "$FindBin::Bin/inc/conf.pl";
}

use strict;

use CPANPLUS::Backend;
use CPANPLUS::Internals::Constants;

use Test::More 'no_plan';
use Data::Dumper;
use File::Basename qw[dirname];

my $conf = gimme_conf();
my $cb   = CPANPLUS::Backend->new( $conf );

isa_ok($cb, "CPANPLUS::Internals" );

my $mt      = $cb->_module_tree;
my $at      = $cb->_author_tree;
my $modname = TEST_CONF_MODULE;

for my $name (qw[auth mod dslip] ) {
    my $file = File::Spec->catfile( 
                        $conf->get_conf('base'),
                        $conf->_get_source($name)
                );            
    ok( (-e $file && -f _ && -s _), "$file exists" );
}    

ok( scalar keys %$at,           "Authortree loaded successfully" );
ok( scalar keys %$mt,           "Moduletree loaded successfully" );

### test lookups
{   my $auth    = $at->{'EUNOXS'};
    my $mod     = $mt->{$modname};

    isa_ok( $auth,              'CPANPLUS::Module::Author' );
    isa_ok( $mod,               'CPANPLUS::Module' );
}


### check custom sources
### XXX whitebox test
{   ### first, find a file to serve as a source
    my $mod     = $mt->{$modname};
    my $package = File::Spec->rel2abs(
                        File::Spec->catfile( 
                            $FindBin::Bin,
                            TEST_CONF_CPAN_DIR,
                            $mod->path,
                            $mod->package,
                        )
                    );      
       
    ok( $package,               "Found file for custom source" );
    ok( -e $package,            "   File '$package' exists" );
    
    ### next, set up the sources file
    my $src_dir = File::Spec->catdir( 
                        $conf->get_conf('base'),
                        $conf->_get_build('custom_sources'),
                    );          
    
    ok( $src_dir,               "Setting up source dir" );
    ok( $cb->_mkdir( dir => $src_dir ),
                                "   Dir '$src_dir' created" );
    
    ### the file we have to write the package names *into*
    my $src_file = File::Spec->catdir(
                        $src_dir,    
                        $cb->_uri_encode(
                            uri =>'file://'.File::Spec->catfile(
                                                dirname($package) 
                                            )
                        )
                    );            
    ok( $src_file,              "Sources will be written to '$src_file'" );                     
                     
    ### and write the file   
    {   my $meth = '__write_custom_module_index';
        can_ok( $cb,    $meth );

        my $rv = $cb->$meth( 
                        path => dirname( $package ),
                        to   => $src_file
                    );

        ok( $rv,                "   Sources written" );
        ok( -e $src_file,       "       Source file exists" );
    }              
    
    ### let's see if we can find our custom files
    {   my $meth = '__list_custom_module_sources';
        can_ok( $cb,    $meth );
        
        my %files = $cb->$meth;
        ok( scalar(keys(%files)),
                                "   Got list of sources" );
        ok( $files{ $src_file },"   Found proper entry" );
    }        

    ### now we can have it be loaded in
    {   my $meth = '__create_custom_module_entries';
        can_ok( $cb,    $meth );

        ### now add our own sources
        ok( $cb->$meth,         "Sources file loaded" );

        my $add_name = TEST_CONF_INST_MODULE;
        my $add      = $mt->{$add_name};
        ok( $add,               "   Found added module" );

        ok( $add->status->_fetch_from,  
                                "       Full download path set" );
        is( $add->author->cpanid, CUSTOM_AUTHOR_ID,
                                "       Attributed to custom author" );

        ### since we replaced an existing module, there should be
        ### a message on the stack
        like( CPANPLUS::Error->stack_as_string, qr/overwrite module tree/i,
                                "   Addition message recorded" );
    }

    ### test updating custom sources
    {   my $meth    = '__update_custom_module_sources';
        can_ok( $cb,    $meth );
        
        ### mark what time it is now, sleep 1 second for better measuring
        my $now     = time;        
        sleep 1;
        
        my $ok      = $cb->$meth;

        ok( $ok,                    "Custom sources updated" );
        cmp_ok( [stat $src_file]->[9], '>=', $now,
                                    "   Timestamp on sourcefile updated" );    
    }

    ### now update using the higher level API, see if it's part of the update
    {   CPANPLUS::Error->flush;

        ### mark what time it is now, sleep 1 second for better measuring
        my $now = time;        
        sleep 1;
        
        my $ok  = $cb->_build_trees(
                        uptodate    => 0,
                        use_stored  => 0,
                    );
    
        ok( $ok,                    "All sources updated" );
        cmp_ok( [stat $src_file]->[9], '>=', $now,
                                    "   Timestamp on sourcefile updated" );    

        like( CPANPLUS::Error->stack_as_string, qr/Updating sources from/,
                                    "   Update recorded in the log" );
    }

}

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:
