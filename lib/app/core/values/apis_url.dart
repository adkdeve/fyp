import '../core.dart';

class ApisUrl {

  // Auth Section
  static const String login = '${AppConfig.baseUrl}login';
  static const String signUp = '${AppConfig.baseUrl}register';
  static const String emailVerify = '${AppConfig.baseUrl}email/verify';
  static const String resendOtp = '${AppConfig.baseUrl}resend/otp';
  static const String resetPassword = '${AppConfig.baseUrl}reset/password';
  static const String updateInfo = '${AppConfig.baseUrl}update/info';

  // User
  static const String getUser = '${AppConfig.baseUrl}user';

  // Jobs
  static const String getJobs = '${AppConfig.baseUrl}jobs';
  static const String getRecommendedJobs = '${AppConfig.baseUrl}recommended/jobs';
  static const String jobFav = '${AppConfig.baseUrl}job/favorite/';
  static const String getFavJob = '${AppConfig.baseUrl}get/favorities';
  static const String getJobDetails = '${AppConfig.baseUrl}job/details/';

  // Company
  static const String getCompanyDetails = '${AppConfig.baseUrl}company/details/';

  // Job Alerts
  static const String getJobAlerts = '${AppConfig.baseUrl}get/job-alert';
  static const String addJobAlerts = '${AppConfig.baseUrl}store/job-alert';
  static const String deleteJobAlerts = '${AppConfig.baseUrl}delete/job-alert/';

  // Resume
  static const String getResume = '${AppConfig.baseUrl}get/resume';
  static const String updateResume = '${AppConfig.baseUrl}update/resume';
  static const String uploadResume = '${AppConfig.baseUrl}upload/resume';

  // Applications
  static const String getFullTimeApplications = '${AppConfig.baseUrl}applications/full%20time';
  static const String getPartTimeApplications = '${AppConfig.baseUrl}applications/part%20time';
  static const String getRemoteApplications = '${AppConfig.baseUrl}applications/remote';
  static const String getContractApplications = '${AppConfig.baseUrl}applications/contract';

  // Settings
  static const String getSettings = '${AppConfig.baseUrl}get/setting';
  static const String updateSettings = '${AppConfig.baseUrl}update/setting';

  // Profile Update
  static const String updateProfile = '${AppConfig.baseUrl}update/profile';



}
