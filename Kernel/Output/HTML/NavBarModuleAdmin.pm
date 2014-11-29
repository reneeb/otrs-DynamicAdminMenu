# --
# Kernel/Output/HTML/NavBarModuleAdmin.pm
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# Changes Copyright (C) 2011-2014 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::NavBarModuleAdmin;

use strict;
use warnings;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for (qw(ConfigObject LogObject DBObject TicketObject LayoutObject UserID)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # only show it on admin start screen
    return '' if $Self->{LayoutObject}->{Action} ne 'Admin';

    # generate manual link
    my $ManualVersion = $Self->{ConfigObject}->Get('Version');
    $ManualVersion =~ m{^(\d{1,2}).+};
    $ManualVersion = $1;

    $Self->{LayoutObject}->Block(
        Name => 'AdminNavBar',
        Data => {
            ManualVersion => $ManualVersion,
        },
    );
# ---
# DynamicAdminMenu
# ---
    # get all configured blocks
    my $Blocks       = $Self->{ConfigObject}->Get('Admin::Menu');
    my @SortedBlocks = sort{ $Blocks->{$a}->{Position} <=> $Blocks->{$b}->{Position} }keys %{$Blocks};
# ---

    # get all Frontend::Module
    my %NavBarModule;
    my $FrontendModuleConfig = $Self->{ConfigObject}->Get('Frontend::Module');
    MODULE:
    for my $Module ( sort keys %{$FrontendModuleConfig} ) {
        my %Hash = %{ $FrontendModuleConfig->{$Module} };
        if (
            $Hash{NavBarModule}
            && $Hash{NavBarModule}->{Module} eq 'Kernel::Output::HTML::NavBarModuleAdmin'
            )
        {

            # check permissions (only show accessable modules)
            my $Shown = 0;
            for my $Permission (qw(GroupRo Group)) {

                # array access restriction
                if ( $Hash{$Permission} && ref $Hash{$Permission} eq 'ARRAY' ) {
                    for ( @{ $Hash{$Permission} } ) {
                        my $Key = 'UserIs' . $Permission . '[' . $_ . ']';
                        if (
                            $Self->{LayoutObject}->{$Key}
                            && $Self->{LayoutObject}->{$Key} eq 'Yes'
                            )
                        {
                            $Shown = 1;
                        }

                    }
                }

                # scalar access restriction
                elsif ( $Hash{$Permission} ) {
                    my $Key = 'UserIs' . $Permission . '[' . $Hash{$Permission} . ']';
                    if ( $Self->{LayoutObject}->{$Key} && $Self->{LayoutObject}->{$Key} eq 'Yes' ) {
                        $Shown = 1;
                    }
                }

                # no access restriction
                elsif ( !$Hash{GroupRo} && !$Hash{Group} ) {
                    $Shown = 1;
                }

            }
            next MODULE if !$Shown;

# ---
# DynamicAdminMenu
# ---
            my $BlockName = $Hash{NavBarModule}->{Block} || 'Item';
# ---
            my $Key = sprintf( "%07d", $Hash{NavBarModule}->{Prio} || 0 );
            COUNT:
            for ( 1 .. 51 ) {
# ---
# DynamicAdminMenu
# ---
#                if ( $NavBarModule{$Key} ) {
                if ( $NavBarModule{$BlockName}->{$Key} ) {
# ---
                    $Hash{NavBarModule}->{Prio}++;
                    $Key = sprintf( "%07d", $Hash{NavBarModule}->{Prio} );
                }
# ---
# DynamicAdminMenu
# ---
#                if ( !$NavBarModule{$Key} ) {
                if ( !$NavBarModule{$BlockName}->{$Key} ) {
# ---
                    last COUNT;
                }
            }
# ---
# DynamicAdminMenu
# ---
#            $NavBarModule{$Key} = {
            $NavBarModule{$BlockName}->{$Key} = {
# ---
                'Frontend::Module' => $Module,
                %Hash,
                %{ $Hash{NavBarModule} },
            };

        }
    }
# ---
# DynamicAdminMenu
# ---
#    my %Count;
#    for my $Module ( sort keys %NavBarModule ) {
#        my $BlockName = $NavBarModule{$Module}->{NavBarModule}->{Block} || 'Item';
#        $Self->{LayoutObject}->Block(
#            Name => $BlockName,
#            Data => $NavBarModule{$Module},
#        );
#        if ( $Count{$BlockName}++ % 2 ) {
#            $Self->{LayoutObject}->Block( Name => $BlockName . 'Clear' );
#        }
#    }

    my @Data;
    for my $BlockName (@SortedBlocks) {
        my $ItemsForBlock = $NavBarModule{$BlockName};
        my @Items         = map{ $ItemsForBlock->{$_} }sort keys %{$ItemsForBlock};
        push @Data, {
            Title => $Blocks->{$BlockName}->{Title},
            Items => \@Items,
        };
    }

    my @TabulatedData = $Self->_Tabulate( Data => \@Data );

    my $Counter = 1;
    for my $Row ( @TabulatedData ) {

        # activate row
        $Self->{LayoutObject}->Block(
            Name => 'Row',
            Data => { RowNumber => $Counter },
        );

        # show blocks
        for my $BlockData ( @{$Row} ) {
            $Self->{LayoutObject}->Block(
                Name => 'Block',
                Data => $BlockData,
            );

            # show items of the block
            my $ItemsCounter = 1;
            my $Items        = $BlockData->{Items} || [];
            for my $Item ( @{$Items} ) {
                $Self->{LayoutObject}->Block(
                    Name => 'Item',
                    Data => $Item,
                );

                if ( $ItemsCounter++ % 2 == 0 ) {
                    $Self->{LayoutObject}->Block( Name => 'ItemClear' );
                }
            }
        }

        $Counter++;
    }
# ---

    my $Output = $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminNavigationBar',
        Data         => \%Param,
    );

    return $Output;
}

# ---
# DynamicAdminMenu
# ---
sub _Tabulate {
    my ( $Self, %Param ) = @_;
    
    my @Data  = @{ $Param{Data} || [] };
    my $Nr    = scalar @Data;
    my $Cols  = 3;
    my $Index = $Cols - 1;
    
    # tabulate data
    my @TmpData;
    while ( $Index < $Nr ) {
        my $Start = $Index - $Cols + 1;
        push @TmpData, [ @Data[ $Start .. $Index ] ];
        $Index += $Cols;
    }
               
    my $Rest = ( $Cols - ( $Nr % $Cols ) ) % $Cols;
    if($Rest > 0){
        
        my $Start = $Nr - ( $Cols - $Rest );
        my $End   = $Nr - 1;
        
        push @TmpData, [
            @Data[$Start..$End],
            (undef) x $Rest,
        ];
    }
    
    return @TmpData;
}
# ---

1;
