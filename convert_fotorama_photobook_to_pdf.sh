 #!/bin/bash

# Copyright 2016 - Gert Hulselmans
#
# Purpose:
#   Convert flash based fotorama photobook from http://foto.com to PDF.

usage () {
    printf "\nUsage:   %s '<fotorama_url>' <fotorama_pdf>\n\n" "${0}";
    printf "         with fotorama URL in the form of:\n"
    printf "            'http://fotorama.foto.com/flash/share_display_direct.php?id_pedido=XXXXXXXXXXXXXXXXXXX&email=your.email@test.com'\n\n";
    printf 'Purpose: Convert flash based fotorama photobook from http://foto.com to PDF.\n\n'
    exit 1;
}


# Check if a certain program is installed (return 0) or not (returns 1).
program_installed () {
    local program="${1}";

    return $(type "${program}" > /dev/null 2>&1 ; echo $?);
}


# Check if all needed dependencies are installed.
check_dependencies () {
    program_installed curl || { printf '\n"curl" could not be found:\n    sudo apt-get install curl\n\n'; exit 1; };
    program_installed grep || { printf '\n"grep" could not be found:\n    sudo apt-get install grep\n\n'; exit 1; };
    program_installed iconv || { printf '\n"iconv" could not be found:\n    sudo apt-get install libc-bin\n\n'; exit 1; };
    program_installed identify || { printf '\n"identify" could not be found:\n    sudo apt-get install imagemagick\n\n'; exit 1; };
    program_installed mktemp || { printf '\n"mktemp" could not be found:\n    sudo apt-get install coreutils\n\n'; exit 1; };
    program_installed montage || { printf '\n"montage" could not be found:\n    sudo apt-get install imagemagick\n\n'; exit 1; };
    program_installed realpath || { printf '\n"realpath" could not be found:\n    sudo apt-get install coreutils\n\n'; exit 1; };
}



# Check if this script is invoked with two arguments.
if [ ${#@} -ne 2 ] ; then
    usage;
fi

check_dependencies;

fotorama_url="${1}";
fotorama_pdf_filename="${2}";


if [ "${fotorama_url:0:66}" != 'http://fotorama.foto.com/flash/share_display_direct.php?id_pedido=' ] ; then
    printf '\nError: fotorama URL does not start with "http://fotorama.foto.com/flash/share_display_direct.php?id_pedido="\n\n';
    exit 1;
fi

if [ "${fotorama_pdf_filename:((${#fotorama_pdf_filename} - 4))}" != '.pdf' ] ; then
    printf '\nError: fotorama output PDF filename should end with ".pdf"\n\n';
    exit 1;
fi


# Get absolute path for fotorama PDF output file.
fotorama_pdf_realpath_filename=$(realpath "${fotorama_pdf_filename}");


# Create a temporary directory to store each page of the fotorama.
fotorama_tmp_dir=$(mktemp -d -t "$(basename "${fotorama_pdf_filename}").XXXXXX");

cd "${fotorama_tmp_dir}";


printf '\nDownload the fotorama HTML page and extract the link to the XML file...\n\n';

fotorrama_xml_url=$(curl "${fotorama_url}" | grep -o 'http://fotorama.foto.com/.*xml');


printf '\nDownload the XML file and extract all pages (share[0-9]+.jpg)...\n\n';

fotorama_pages=$(
    curl "${fotorrama_xml_url}" \
        | iconv -c --from-code UTF16BE --to-code ASCII \
        | grep -oE 'http://fotorama.foto.com/datas/[^"]*share[0-9]+.jpg'
)

fotorama_pages_1x1='';
fotorama_pages_2x1='share0.jpg';

for fotorama_page in ${fotorama_pages} ; do
    # Only keep the basename of the fotorama page.
    basename_fotorama_page=$(basename "${fotorama_page}");

    # Add each page in order they appear in the XML file for 1x1 PDF version.
    fotorama_pages_1x1="${fotorama_pages_1x1} ${basename_fotorama_page}";

    if [ "${basename_fotorama_page}" != 'share0.jpg' ] ; then
        # Add each page in order they appear in the XML file for 2x1 PDF version,
        # except the last page as we added it in the beginning.
        fotorama_pages_2x1="${fotorama_pages_2x1} ${basename_fotorama_page}";
    fi

    printf '\nDownloading page "%s"...\n\n' "${basename_fotorama_page}";

    curl -O "${fotorama_page}";
done


# Get geometry of a page.
geometry=$(identify share1.jpg | cut -f 3 -d ' ');

printf '\n\nCreate 1x1 PDF...\n\n';

montage -tile 1x1 -geometry "${geometry}" -compress jpeg ${fotorama_pages_1x1} "${fotorama_pdf_realpath_filename%.pdf}.1x1.pdf";

printf 'The 1x1 fotorama PDF can be found at "%s".\n\n' "${fotorama_pdf_realpath_filename%.pdf}.1x1.pdf";

printf 'Create 2x1 PDF...\n\n';

montage -tile 2x1 -geometry "${geometry}" -compress jpeg ${fotorama_pages_2x1} "${fotorama_pdf_realpath_filename%.pdf}.2x1.pdf";

printf 'The 2x1 fotorama PDF can be found at "%s".\n\n' "${fotorama_pdf_realpath_filename%.pdf}.2x1.pdf";

exit 0;
