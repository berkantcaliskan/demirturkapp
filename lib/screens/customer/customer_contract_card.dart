import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/portal_repository.dart';
import '../../widgets/contract_document_button.dart';
import '../../widgets/website_blurred_background.dart';

class CustomerContractCard extends StatelessWidget {
  const CustomerContractCard({
    super.key,
    required this.customer,
    this.repository,
  });

  final Customer customer;
  final PortalRepository? repository;

  @override
  Widget build(BuildContext context) {
    final hasContract =
        customer.contractNo.isNotEmpty && !customer.contractPending;
    final currentRepository = repository;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasContract
                ? customer.contractNo
                : 'Henüz hesabınıza sözleşme eklenmedi.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppGlass.textPrimary(context),
            ),
          ),
          if (hasContract && customer.projectName?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              customer.projectName!,
              style: TextStyle(color: AppGlass.textSecondary(context)),
            ),
          ],
          if (hasContract &&
              customer.contractDocumentPath != null &&
              currentRepository != null)
            ContractDocumentButton(
              repository: currentRepository,
              customerId: customer.id,
            )
          else if (hasContract)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Sözleşme dosyası henüz eklenmedi.'),
            ),
        ],
      ),
    );
  }
}
