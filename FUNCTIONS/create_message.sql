CREATE OR REPLACE FUNCTION Create_Message(OUT MessageID text, _Plaintext text, _MessageType text, _FromBankID text, _ToBankID text) RETURNS TEXT
SET search_path TO public, pg_temp
AS $BODY$
DECLARE
_FileID text;
_SignatureKeyID text;
_EncryptionKeyID text;
_Cipherdata bytea;
_OK boolean;
BEGIN

_FileID := encode(digest(_Plaintext,'sha512'),'hex');
IF NOT EXISTS (SELECT 1 FROM Files WHERE FileID = _FileID) THEN
    INSERT INTO Files (FileID, Plaintext) VALUES (_FileID, _Plaintext) RETURNING TRUE INTO STRICT _OK;
END IF;

SELECT Messages.MessageID INTO MessageID FROM Messages WHERE FileID = _FileID AND MessageType = _MessageType AND FromBankID = _FromBankID AND ToBankID = _ToBankID;
IF FOUND THEN
    RETURN;
END IF;

SELECT MainKeyID INTO STRICT _SignatureKeyID  FROM Keys WHERE BankID = _FromBankID AND PrimaryKey IS TRUE;
SELECT SubKeyID  INTO STRICT _EncryptionKeyID FROM Keys WHERE BankID = _ToBankID   AND PrimaryKey IS TRUE;

_Cipherdata := Encrypt_Sign(_Plaintext, _EncryptionKeyID, _SignatureKeyID);
MessageID := encode(digest(_Cipherdata,'sha512'),'hex');

INSERT INTO Messages (MessageID,  MessageType,  FileID,  FromBankID,  ToBankID,  Cipherdata, MessageState)
VALUES               (MessageID, _MessageType, _FileID, _FromBankID, _ToBankID, _Cipherdata, 'SENDING')
RETURNING TRUE INTO STRICT _OK;

RETURN;
END;
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;
