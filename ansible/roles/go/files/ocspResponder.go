package main

import (
	"bytes"
	"crypto"
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"flag"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"golang.org/x/crypto/ocsp"
	"gopkg.in/yaml.v2"
)

var (
	timeout          int
	testCount        int
	allPath          string
	haConfDir        string
	debug            bool
	isFrontendServer bool
	allFile          GroupVarsAll
)

type GroupVarsAll struct {
	ConfigDone                 string `yaml:"config_done"`
	ExternalHostname           string
	HTTPProxy                  string `yaml:"http_proxy"`
	SslServerCertificate       string `yaml:"ssl_server_certificate"`
	SslIntermediateCertificate string `yaml:"ssl_intermediate_certificate"`
	SslRootCertificate         string `yaml:"ssl_root_certificate"`
	SslKeyfile                 string `yaml:"ssl_keyfile"`
}

func main() {
	parseCMDArgs()

	debugMSG("Test if running on a frontend server...")
	isFrontendServer = checkIsFrontendServer()

	debugMSG("Going to parse group_vars/all file")
	allFile = readGroupVarsAll(allPath)

	debugMSG("Start parsing server certificate...")
	var certX509 x509.Certificate = readCertPEM(allFile.SslServerCertificate)
	debugMSG("Start parsing root certificate...")
	//var rootX509 x509.Certificate = readCertPEM(allFile.SslRootCertificate)
	debugMSG("Start parsing intermediate...")
	var intmX509 x509.Certificate = readCertPEM(allFile.SslIntermediateCertificate)

	debugMSG("Starting tests...")
	// WARN IF CONFIG_DONE IS NOT TRUE OR NOT DEFINED
	if len(allFile.ConfigDone) == 0 || !strings.EqualFold(allFile.ConfigDone, "true") {
		log.Println("[WARNING] config done is not true or not defined!")
	}
	testCount++
	debugMSG("[OK] Config done was set")
	//CHECK CERTIFICATE PATH EXISTS
	if _, err := os.Stat(allFile.SslServerCertificate); os.IsNotExist(err) {
		log.Fatal("Server certificate does not exists or path is wrong!")
	}
	testCount++
	debugMSG("[OK] certificate path was set")
	//CHECK ROOT PATH EXISTS
	if _, err := os.Stat(allFile.SslRootCertificate); os.IsNotExist(err) {
		log.Fatal("Root certificate does not exists or path is wrong!")
	}
	testCount++
	debugMSG("[OK] root path was set")
	//CHECK INTERMEDIATE PATH EXISTS
	if _, err := os.Stat(allFile.SslIntermediateCertificate); os.IsNotExist(err) {
		log.Fatal("Root certificate does not exists or path is wrong!")
	}
	testCount++
	debugMSG("[OK] Intermediate path was set")
	// TEST THAT CERTIFICATE IS NOT SELF SIGNED
	if bytes.Compare(certX509.RawIssuer, certX509.RawSubject) == 0 {
		log.Println("[WARNING] Certificate is self signed. This is not supported by teamwire")
	}
	testCount++
	debugMSG("[OK] certificate is not self signed")
	// VERIFY THAT HOSTNAME MATCH CERTIFICATE
	if err := certX509.VerifyHostname(allFile.ExternalHostname); err != nil {
		if !isFrontendServer {
			log.Fatal("External_hostname does not match certificate hostname in ", err)
		}
		log.Println("[SKIPPED] Skip hostname test on frontend server.Return dummy test was successful")
	}
	testCount++
	debugMSG("[OK] Hostname match certificate host")
	//CHECK IF CERTIFICATE IS NOT EXPIRED
	if time.Now().Sub(certX509.NotAfter).Seconds() >= 0.0 {
		log.Fatal("Server certificate is expired. Please renew your certificate")
	}
	testCount++
	debugMSG("[OK] Certificate is not expired")
	if _, err := tls.LoadX509KeyPair(allFile.SslServerCertificate, allFile.SslKeyfile); err != nil {
		log.Fatal("Key does not match certificate ", err)
	}
	testCount++
	debugMSG("[OK] Private key match certificate")
	//CHECK IF OCSP SERVER ENTRY EXISTS
	if len(certX509.OCSPServer) == 0 {
		log.Fatal("No ocsp server entry found in certificate")
	}
	testCount++
	debugMSG("[OK] Responder for ocsp request found")
	//CHECK FOR OCSP RESPONSE
	if isCertificateRevokedByOCSP(&certX509, &intmX509) {
		log.Fatal("OCSP check failed!")
	}
	testCount++

	log.Printf("All %v tests passed. No problems found\n", testCount)
}

func debugMSG(msg string) {
	if debug {
		log.Println("[DEBUG]: ", msg)
	}
}

func parseCMDArgs() {
	flag.StringVar(&allPath, "path-to-all-file", "/home/teamwire/platform/ansible/group_vars/all", "Define where to find group_vars/all")
	flag.StringVar(&haConfDir, "path-to-haconf", "/etc/haproxy", "Define where to find haproxy dir")
	flag.IntVar(&timeout, "timeout", 10, "Define timout for ocsp request")
	flag.BoolVar(&debug, "debug", false, "Enables debugging. Output is more verbose")
	flag.Parse()
}

// external_hostname in group_vars/all can be a single string
// or a list.To catch both cases we need to define a function
// which is able to do so.
func getHostname(ymlFile []byte) string {
	if isFrontendServer {
		debugMSG("Hostname not needed on a frontend server")
		return ""
	}

	type hostSingle struct {
		Hostname string `yaml:"external_hostname"`
	}
	type hostArray struct {
		Hostname []string `yaml:"external_hostname"`
	}

	var hostnameS = hostSingle{}
	var hostnameA = hostArray{}

	err := yaml.Unmarshal(ymlFile, &hostnameS)
	if err != nil {
		err = yaml.Unmarshal(ymlFile, &hostnameA)
		if err != nil {
			log.Fatal("Could not parse group_vars/all file. External_hostname unkown: ", err)
		}
		return hostnameA.Hostname[0]
	}
	return hostnameS.Hostname
}

func readCertPEM(certPath string) x509.Certificate {
	debugMSG("Load cert path: " + certPath)
	certFile, err := ioutil.ReadFile(certPath)
	if err != nil {
		log.Println("[ERROR - readCertPEMfunc1]: ", certPath)
		log.Fatal("Could not read certificate: ", err)
	}
	block, _ := pem.Decode(certFile)
	if block == nil {
		log.Println("[ERROR - readCertPEMfunc2]: ", certPath)
		log.Fatal("failed to decode server certificate")
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		log.Println("[ERROR - readCertPEMfunc3]: ", certPath)
		log.Fatal("Could not parse certificate: ", err)
	}

	return *cert
}

func readGroupVarsAll(path string) GroupVarsAll {
	var yml GroupVarsAll

	if !isFrontendServer {
		ymlFile, err := ioutil.ReadFile(path)
		if err != nil {
			log.Fatal("Could not read group_vars/all file: ", err)
		}
		err = yaml.Unmarshal(ymlFile, &yml)
		if err != nil {
			log.Fatal("Could not unmarschal group_vars/all to yaml: ", err)
		}
		yml.ExternalHostname = getHostname(ymlFile)
		return yml
	}
	return createFrontendDummyConf()
}

func isCertificateRevokedByOCSP(clientCert, issuerCert *x509.Certificate) bool {
	opts := &ocsp.RequestOptions{Hash: crypto.SHA1}
	buffer, err := ocsp.CreateRequest(clientCert, issuerCert, opts)
	if err != nil {
		return false
	}
	httpRequest, err := http.NewRequest(http.MethodPost, clientCert.OCSPServer[0], bytes.NewBuffer(buffer))
	if err != nil {
		return false
	}
	ocspUrl, err := url.Parse(clientCert.OCSPServer[0])
	if err != nil {
		return false
	}
	httpRequest.Header.Add("Content-Type", "application/ocsp-request")
	httpRequest.Header.Add("Accept", "application/ocsp-response")
	httpRequest.Header.Add("host", ocspUrl.Host)

	var httpClient *http.Client
	if len(allFile.HTTPProxy) == 0 {
		log.Println("ocsp: starting request without proxy...")
		httpClient = &http.Client{
			Timeout: time.Second * 10,
		}
	} else {
		log.Println("ocsp: starting request with proxy...")
		proxy, err := url.Parse(allFile.HTTPProxy)
		if err != nil {
			log.Fatal("ocsp: Can not parse proxy url.")
		}
		httpClient = &http.Client{
			Transport: &http.Transport{
				Dial: (&net.Dialer{
					Timeout:   time.Duration(timeout) * time.Second,
					KeepAlive: time.Duration(timeout) * time.Second,
				}).Dial,
				Proxy: http.ProxyURL(proxy)},
		}
	}
	httpResponse, err := httpClient.Do(httpRequest)
	if err != nil {
		log.Println("ocsp: request error ", err)
		return true
	}
	defer httpResponse.Body.Close()
	output, err := ioutil.ReadAll(httpResponse.Body)
	if err != nil {
		log.Println("Could not parse http response: ", err)
		return true
	}
	ocspResponse, err := ocsp.ParseResponse(output, issuerCert)
	if err != nil {
		log.Println("Could not parse ocsp response: ", err)
		return true
	}
	switch ocspResponse.Status {
	case ocsp.Good:
		log.Println("ocsp: response looks good")
		//Filepath could also be specified as var ?!
		ocspFile, err := os.Create("/etc/ssl/certs/server_and_intermediate_and_root.crt.ocsp")
		if err != nil {
			log.Println("Could not create ocsp cert file")
			return true
		}
		defer ocspFile.Close()
		ocspFile.Write(output)
		return false
	case ocsp.Revoked:
		log.Println("ocsp: certificate has been revoked (either permanantly or temporarily (on hold))")
		return true
	case ocsp.Unknown:
		log.Println("ocsp: the responder doesn't know about the certificate being requested")
		return true
	case ocsp.ServerFailed:
		log.Println("ocsp: the OCSP responder failed to process the request")
		return true
	default:
		log.Println("ocsp: unrecognised status")
		return true
	}
}

func checkIsFrontendServer() bool {
	if _, err := os.Stat(allPath); os.IsNotExist(err) {
		if _, err := os.Stat(haConfDir); !os.IsNotExist(err) {
			return true
		}
	}
	return false
}

// createFrontendDummyConf creates an dummy config in case
// ocspResponder is running on a frontend server. Normaly
// frontend server dont have a group_vars/all file to parse,
// hence we return a dummy conf.
func createFrontendDummyConf() GroupVarsAll {
	return GroupVarsAll{
		ConfigDone:                 "true",
		ExternalHostname:           "",
		HTTPProxy:                  os.Getenv("http_proxy"),
		SslServerCertificate:       "/etc/ssl/certs/teamwire.server.crt",
		SslIntermediateCertificate: "/etc/ssl/certs/teamwire.intermediate.crt",
		SslRootCertificate:         "/etc/ssl/certs/teamwire.root.crt",
		SslKeyfile:                 "/etc/ssl/private/teamwire-backend.key",
	}
}
