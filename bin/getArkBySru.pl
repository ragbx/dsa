#! /usr/bin/perl

=pod

=encoding UTF-8

=head1 DESCRIPTION

Ce script prend en entrée un fichier MARC ISO 2709.
Pour chaque notice, on extrait via Catamndu l'isbn et / ou l'ean.
On effectue ensuite via Catmandu une recherche sur le serveur SRU de la BnF (avec pour clé de recherche soit l'isbn, soit l'ean) et, en cas de récupération de notices, on extrait de celles-ci l'identifiant ark.

=cut

use strict;
use warnings;
use Catmandu;
use Catmandu::Importer::SRU;
use Data::Dumper;

my $importer = Catmandu->importer( 'MARC', type => 'RAW', file => '../input/biblio.mrc' );

my @fix = [
    "marc_map(010a,isbn)",
    "marc_map(073a,ean)",
    "retain(_id, ean, isbn)"
];
my $fixer = Catmandu->fixer(@fix);

$fixer->fix($importer)->each(sub {
    my $data_rbx = shift;
    if ( $data_rbx->{isbn} || $data_rbx->{ean} ) {
        my $query;
        if ( $data_rbx->{isbn} ) {
            $query = "(bib.isbn any \"$data_rbx->{isbn}\")";
        } elsif ( $data_rbx->{ean} ) {
            $query = "(bib.ean any \"$data_rbx->{ean}\")";
        }
        my %attrs = (
            base => "http://catalogue.bnf.fr/api/SRU",
            version => "1.2",
            query => $query,
            recordSchema => "unimarcXchange",
            parser => "marcxml"
        );
 
        my $importer = Catmandu::Importer::SRU->new(%attrs);
        my @fix = [
            "marc_map(003,ark)",
            "retain(ark)"
        ];
        my $fixer = Catmandu->fixer(@fix);
        my @ark;
        eval {        
            $fixer->fix($importer)->each(sub {
                my $record_bnf = shift;
                push @ark, $record_bnf->{ark};
            });
        };
        if ( !$@ ) {
            $data_rbx->{ark_bnf} = \@ark;
            $data_rbx->{resp} = 'OK';
        } else {
            $data_rbx->{resp} = 'KO';
        }
    } else {
        $data_rbx->{resp} = 'KO';
    } 
    print Dumper($data_rbx);
});
