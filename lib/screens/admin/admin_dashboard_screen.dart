YªçŠx-®éÜj×¢ëiºÚ+Š§j[h‘éÜ¢éíß_7Ù:-jZ.¶›­–)Ş³V–×÷'Bw6¶vS¦fÇWGFW"ö7WW'F–æòæF'Bs°Ğ¦–×÷'Bw6¶vS¦fÇWGFW"öÖFW&–ÂæF'Bs°Ğ¦–×÷'Bw6¶vS¦fÇWGFW"÷6W'f–6W2æF'Bs°Ğ¦–×÷'Bw6¶vS¦f–ÆU÷–6¶W"öf–ÆU÷–6¶W"æF'Bs°Ğ¦–×÷'Bw6¶vS§W&ÅöÆVæ6†W"÷W&ÅöÆVæ6†W"æF'Bs°Ğ Ğ¦–×÷'BrââòââöÖöFVÇ2ööÖöFVÇ2æF'Bs°Ğ¦–×÷'Brââòââ÷6W'f–6W2ö÷7FFRæF'Bs°Ğ¦–×÷'Brââòââ÷6W'f–6W2÷÷'FÅ÷&W÷6—F÷'’æF'Bs°Ğ¦–×÷'Brââòââ÷WF–Ç2÷GW&¶—6…÷†öæUö–çWEöf÷&ÖGFW"æF'Bs°Ğ¦–×÷'BvFÖ–å÷7W÷'Eö–æ&÷…÷67&VVâæF'Bs°Ğ¦–×÷'Brââòââ÷v–FvWG2÷vV'6—FUö&ÇW'&VEö&6¶w&÷VæBæF'Bs°Ğ¦–×÷'Brââö7W7FöÖW"ö7W7FöÖW%÷7W÷'E÷67&VVâæF'Bs°Ğ Ğ¦6Æ72FÖ–äF6†&ö&E67&VVâW‡FVæG27FFVÆW75v–FvWB°Ğ¢f–æÂ7FFR7FFS°Ğ¢f–æÂ–çB7F—fUF$–æFWƒ°Ğ¢f–æÂ÷'FÅ&W÷6—F÷'“ò&W÷6—F÷'“°Ğ Ğ¢6öç7BFÖ–äF6†&ö&E67&VVâ‡°Ğ¢7WW"æ¶W’ÀĞ¢&WV—&VBF†—2æ7FFRÀĞ¢&WV—&VBF†—2æ7F—fUF$–æFW‚ÀĞ¢F†—2ç&W÷6—F÷'’ÀĞ¢Ò“°Ğ Ğ¢÷fW'&–FPĞ¢v–FvWB'V–ÆB„'V–ÆD6öçFW‡B6öçFW‡B’°Ğ¢–b†7FFRæ7W'&VçE&öÆRæ—56ÆW4Gf—6÷"’°Ğ¢&WGW&â7v—F6‚†7F—fUF$–æFW‚’°Ğ¢Óâö'V–ÆD7W7FöÖW'5F"†6öçFW‡B’ÀĞ¢Óâö'V–ÆD7W7FöÖW'5F"†6öçFW‡BÂ&ö6W74öæÇ“¢G'VR’ÀĞ¢"ÓàĞ¢&W÷6—F÷'’ÓÒçVÆÀĞ¢òö'V–ÆDÖW76vW5F"†6öçFW‡BĞ¢¢FÖ–å7W÷'D–æ&÷…67&VVâ‡&W÷6—F÷'“¢&W÷6—F÷'’’ÀĞ¢2ÓàĞ¢&W÷6—F÷'’ÓÒçVÆÀĞ¢òö'V–ÆDÖW76vW5F"†6öçFW‡BĞ¢¢FÖ–å7W÷'D–æ&÷…67&VVâ€Ğ¢&W÷6—F÷'“¢&W÷6—F÷'’ÀĞ¢6Æ÷6VDöæÇ“¢G'VRÀĞ¢’ÀĞ¢ôó}­¢G§²ÚîÆ­yĞ_folderId
                  : null,
              hint: const Text(
                'KlasÃ¶re ekle',
                style: TextStyle(color: Color(0xFF64D2FF), fontSize: 12),
              ),
              dropdownColor: const Color(0xFF242220),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('KlasÃ¶rsÃ¼z'),
                ),
                ...folders.map(
                  (folder) => DropdownMenuItem<String?>(
                    value: folder['id'].toString(),
                    child: Text(folder['name'].toString()),
                  ),
                ),
              ],
              onChanged: (value) async {
                setState(() => _folderId = value);
                try {
                  await widget.repository.assignCustomerFolder(
                    customerId: widget.customer.id,
                    folderId: value,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('KlasÃ¶r atamasÄ± yapÄ±lamadÄ±: $error'),
                      ),
                    );
                  }
                }
              },
            ),
          );
        },
      );
}
