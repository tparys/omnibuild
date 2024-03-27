#include <unistd.h>
#include <string>
#include <string.h>
#include <libgen.h>
#include <cstdio>

int main(int argc, char **argv)
{
    // Convert: /usr/libexec/qemu-binfmt/<aarch64>-binfmt-P
    //      to: /usr/bin/qemu-<ARCH>
    std::string qemu = basename(argv[0]);
    std::size_t pos = qemu.find("-");
    if (pos != std::string::npos)
    {
	qemu = qemu.substr(0, pos);
    }
    qemu = "/usr/bin/qemu-" + qemu;

    // Allocate some space for a new argv
    //  - First is rewritten to point to qemu
    //  - Second dropped (duplicate of third)
    //  - Rest shifted left one
    char **argv_new = (char**)calloc(argc, sizeof(char*));
    argv_new[0] = strdup(qemu.c_str());
    for (int i = 2; i < argc; i++)
    {
	argv_new[i-1] = argv[i];
    }
    // Last left at zero per calloc()

    // Pass control
    return execv(argv_new[0], argv_new);
}
