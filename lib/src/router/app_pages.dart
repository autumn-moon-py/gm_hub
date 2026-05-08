import 'package:get/get.dart';

import '../controller/project_controller.dart';
import '../ui/main_shell.dart';
import 'app_routes.dart';

class AppPages {
  static List<GetPage<dynamic>> routes({
    String? initialProjectFilePath,
  }) {
    return [
      GetPage(
        name: AppRoutes.main,
        page: () => const MainShell(),
        binding: BindingsBuilder(() {
          if (!Get.isRegistered<ProjectController>()) {
            Get.put(
              ProjectController(
                initialProjectFilePath: initialProjectFilePath,
              ),
            );
          }
        }),
      ),
    ];
  }
}
