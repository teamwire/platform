package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"golang.org/x/crypto/openpgp/packet"

	"golang.org/x/crypto/openpgp/armor"
	"gopkg.in/ini.v1"
)

const (
	GPGV string = "/usr/bin/gpg"
	GPGH string = "/data/archiving/gpg/"
)

var (
	archivingPath   string
	tag             string
	publicKeyFile   string
	gpgHomedir      string = GPGH
	gpgVersion      string = GPGV
	gpgCommand      string
	archivingConf   ini.File
	createUser      bool
	updateUser      bool
	deleteUser      bool
	ownerTrustLevel = map[string]int{
		"never":     1,
		"unknown":   2,
		"undefined": 3,
		"marginal":  4,
		"full":      5,
		"ultimate":  6,
	}
)

func main() {

	parseFlags()
	archivingConf, err := ini.Load(archivingPath)
	if err != nil {
		log.Println("Could not load archiving.conf", err)
	}
	if createUser || updateUser {
		importKey()
		if ok := createNewUser(archivingConf); !ok {
			log.Fatal("There was some error...")
		}
		log.Println("New user was added/updated successfully")
	}
	if deleteUser && (!createUser || !updateUser) {
		if ok := delUser(archivingConf); !ok {
			log.Fatal("Could not delete user")
		}
		log.Println("User was successfully deleted")
	}
}

func parseFlags() {
	flag.StringVar(&archivingPath, "archive-path", "/data/archiving/archiving.conf", "Define path to archiving.conf")
	flag.StringVar(&tag, "tag", "example.de", "Set organization where the key should be added")
	flag.StringVar(&publicKeyFile, "file", "", "Set path to public key file e.g. user.asc")
	flag.BoolVar(&createUser, "add", false, "Add a new user into gpg keystore and archiving.conf")
	flag.BoolVar(&deleteUser, "del", false, "Remove a user from gpg keystore and archiving.conf")
	flag.Parse()
}

func createNewUser(confFile *ini.File) bool {
	mail, id, _ := readPublicKeyFile()
	if len(mail) == 0 || len(id) == 0 {
		log.Fatal("Mail or ID empty...")
		return false
	}
	confFile.Section(tag).Key(mail).SetValue(id)
	err := confFile.SaveTo(archivingPath)
	if err != nil {
		log.Println("[ADD] Could not save archiving.conf file")
		return false
	}
	return true
}

// delUser function will delete the given user from
// archiving but not from gpg keyring. That needs to
// be also implemented
func delUser(confFile *ini.File) bool {
	mail, id, _ := readPublicKeyFile()
	if len(mail) == 0 || len(id) == 0 {
		log.Fatal("Mail or ID empty...")
		return false
	}
	confFile.Section(tag).DeleteKey(mail)
	err := confFile.SaveTo(archivingPath)
	if err != nil {
		log.Println("[DEL] Could not save archiving.conf file")
		return false
	}
	return true
}

func readPublicKeyFile() (email string, id string, finger_print string) {
	pubKey, err := os.Open(publicKeyFile)
	if err != nil {
		log.Fatal("Could not open public key file: ", err)
	}
	defer pubKey.Close()

	pk, err := armor.Decode(pubKey)
	if err != nil {
		log.Fatal("Could not read public key file: ", err)
	}

	reader := packet.NewReader(pk.Body)
	pkt, err := reader.Next()
	if err != nil {
		log.Fatal("Error while reading key")
	}
	key, ok := pkt.(*packet.PublicKey)
	if !ok {
		log.Fatal("Public key is not valid ", err)
	}

	e, err := reader.Next()
	if err != nil {
		log.Fatal(err)
	}
	userID := e.(*packet.UserId)
	fingerprint := strings.ToUpper(hex.EncodeToString(key.Fingerprint[:]))

	return userID.Email, key.KeyIdShortString(), fingerprint
}

// importKey imports a public key into gpg keyring. That keys
// is automatic set to trust level "unlimited"
func importKey() {
	// opengpg lib for golang is not able to read nativ kbx files! Hence we need
	// to use cmdline tools to add ability for importing keys.
	mail, id, fingerprint := readPublicKeyFile()
	if len(mail) == 0 || len(id) == 0 {
		log.Fatal("Mail or ID empty...")
	}

	gpg := exec.Command(gpgVersion, "--homedir", gpgHomedir, "--import", publicKeyFile)
	gpg.Stdout = os.Stdout
	gpg.Stderr = os.Stderr

	err := gpg.Run()
	if err != nil {
		log.Fatal("Error while importing gpg key ", err)
	}

	ownertrust := fmt.Sprintf("%s:%v:", fingerprint, ownerTrustLevel["ultimate"])
	cmdString := fmt.Sprintf("/bin/echo %s| %s --homedir %s --import-ownertrust",
		ownertrust,
		gpgVersion,
		gpgHomedir)

	gpg = exec.Command("bash", "-c", cmdString)
	err = gpg.Run()
	if err != nil {
		log.Fatal("Failed to execute gpg ownertrust command ", err)
	}
	setFilePermission()
}

// setFilePermission execute all commands in cmdlist and set
// the proper permissions for the corresponding files
func setFilePermission() {
	cmdList := []string{
		fmt.Sprintf("chown -R daemon:daemon %s", gpgHomedir),
		fmt.Sprintf("chmod -R go= %s", gpgHomedir),
		fmt.Sprintf("chown root:daemon %s", archivingPath),
		fmt.Sprintf("chmod 0640 %s", archivingPath),
	}
	for _, cmd := range cmdList {
		_, err := exec.Command("bash", "-c", cmd).Output()
		if err != nil {
			log.Fatalf("Failed to execute command '%s' with error: %s\nPlease check permisson and/or ownership.", cmd, err.Error())
		}
	}
}
