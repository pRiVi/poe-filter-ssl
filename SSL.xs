#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <openssl/ssl.h>
#include <openssl/bio.h>

MODULE = POE::Filter::SSL      PACKAGE = POE::Filter::SSL

ASN1_INTEGER *
X509_get_serialNumber(cert)
   X509 *      cert
   CODE:
      RETVAL = X509_get_serialNumber(cert);
      ST(0) = sv_newmortal();   /* Undefined to start with */
      sv_setpvn( ST(0), RETVAL->data, RETVAL->length);

ASN1_INTEGER *
verify_serial_against_crl_file(crlfile, serial)
   CODE:
   X509_CRL *crl=NULL;
   X509_REVOKED *revoked;
   BIO *in=NULL;
   int n,i,retval = 0;
   STRLEN len, lenser;
   unsigned char* crlfile = SvPV( ST(0), len);
   unsigned char* serial  = SvPV( ST(1), lenser);
   ST(0) = sv_newmortal();   /* Undefined to start with */

   /* check peer cert against CRL */
   if (len <= 0) {
      sv_setpvn(ST(0), "CRL: No file name given!", 24);
      goto end;
   }

   in=BIO_new(BIO_s_file());
   if (in == NULL) {
      sv_setpvn(ST(0), "CRL: BIO err", 12);
      goto end;
   }

   if (BIO_read_filename(in, crlfile) <= 0) {
      sv_setpvn(ST(0), "CRL: cannot read CRL File", 25);
      goto end;
   }

   crl=PEM_read_bio_X509_CRL(in,NULL,NULL,NULL);
   if (crl == NULL) {
      sv_setpvn(ST(0), "CRL: cannot read from CRL File", 30);
      goto end;
   }

   n = sk_num(X509_CRL_get_REVOKED(crl));
   if (n > 0) {
      for (i = 0; i < n; i++) {
         revoked = (X509_REVOKED *)sk_value(X509_CRL_get_REVOKED(crl), i);
         if ( (revoked->serialNumber->length > 0) &&
              (revoked->serialNumber->length == lenser) &&
              (strncmp(revoked->serialNumber->data, serial, lenser) == 0)) {
            sv_setpvn( ST(0), revoked->serialNumber->data, revoked->serialNumber->length);
            goto end;
         }
      }
      sv_setpvn(ST(0), "0", 1);
   } else {
      sv_setpvn(ST(0), "CRL: Empty File", 15);
   }
   end:
   BIO_free(in);
   if (crl) X509_CRL_free (crl);
