import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useToast } from '@/hooks/use-toast';
import { useTheme } from '@/context/ThemeContext';
import { ChevronLeft } from 'lucide-react';

function TermsConditions() {
  const { isDarkMode } = useTheme();
  const navigate = useNavigate();
  const { toast } = useToast();
  const [activeTab, setActiveTab] = useState<'terms' | 'privacy'>('terms');

  const handleAccept = () => {
    toast({
      title: 'Accepted',
      description: 'You have accepted the Terms of Service and Privacy Policy.',
    });
    setTimeout(() => {
      navigate('/site');
    }, 500);
  };

  return (
    <div className={`min-h-screen px-4 py-2 ${isDarkMode ? 'bg-gray-900' : 'bg-gray-50'}`}>
      {/* Header */}
      <div className="max-w-4xl  mb-6">
        <div className="flex items-center gap-3 mb-4">
          <button
            onClick={() => navigate(-1)}
            className={`p-2 rounded-lg transition ${isDarkMode ? 'hover:bg-gray-800 text-gray-300' : 'hover:bg-gray-200 text-gray-700'}`}
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
          <div>
            <h1 className={`text-2xl font-bold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>Legal</h1>
            <p className={`text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Terms of Service & Privacy Policy</p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="mx-auto mb-6">
        <div className="grid grid-cols-2 gap-3">
          <button
            onClick={() => setActiveTab('terms')}
            className={`py-3 px-4 rounded-lg font-medium transition ${
              activeTab === 'terms'
                ? 'bg-blue-600 text-white'
                : isDarkMode ? 'bg-gray-800 text-gray-300 hover:bg-gray-700' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            Terms of Service
          </button>
          <button
            onClick={() => setActiveTab('privacy')}
            className={`py-3 px-4 rounded-lg font-medium transition ${
              activeTab === 'privacy'
                ? 'bg-blue-600 text-white'
                : isDarkMode ? 'bg-gray-800 text-gray-300 hover:bg-gray-700' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            Privacy Policy
          </button>
        </div>
      </div>

      {/* Content */}
      <div className={`mx-auto rounded-lg p-6 mb-6 space-y-6 ${isDarkMode ? 'bg-gray-800' : 'bg-white'}`}>
        {activeTab === 'terms' ? (
          <div className={`space-y-4 ${isDarkMode ? 'text-gray-300' : 'text-gray-800'}`}>
            <h2 className={`text-xl font-bold ${isDarkMode ? 'text-white' : ''}`}>2. Use License</h2>
            <p>
              Permission is granted to use the Service for construction site safety monitoring purposes under the following conditions:
            </p>
            <ul className={`list-disc list-inside space-y-2 ${isDarkMode ? 'text-gray-400' : 'text-gray-700'}`}>
              <li>The Service is used solely for workplace safety monitoring</li>
              <li>You maintain the confidentiality of your account credentials</li>
              <li>You comply with all applicable safety regulations and laws</li>
              <li>You do not attempt to reverse engineer or hack the AI detection system</li>
            </ul>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>3. AI Detection Disclaimer</h2>
            <p>
              While our AI-powered detection system achieves high accuracy rates (90%+), it should not replace human supervision and judgment. The Service is designed to assist safety monitoring, not replace comprehensive safety protocols. Users are responsible for verifying all violations and taking appropriate action.
            </p>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>4. Data Collection and Camera Use</h2>
            <p>
              You agree that the Service will collect video footage and safety violation data from construction sites. All parties working on monitored sites must be informed of camera surveillance and AI monitoring in compliance with local privacy laws.
            </p>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>5. Limitation of Liability</h2>
            <p>
              The Service providers shall not be held liable for any incidents, accidents, or safety violations that occur despite the use of the monitoring system. The Service is a tool to enhance safety, not guarantee it.
            </p>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>6. Service Modifications</h2>
            <p>
              We reserve the right to modify or discontinue the Service at any time without notice. We may also update these terms periodically, and continued use of the Service constitutes acceptance of modified terms.
            </p>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>7. Account Termination</h2>
            <p>
              We may terminate or suspend your account and access to the Service immediately, without prior notice or liability, for any reason, including breach of these Terms.
            </p>
          </div>
        ) : (
          <div className={`space-y-4 ${isDarkMode ? 'text-gray-300' : 'text-gray-800'}`}>
            <h2 className={`text-xl font-bold ${isDarkMode ? 'text-white' : ''}`}>Privacy Policy</h2>
            <p>
              We are committed to protecting your privacy and ensuring you have a positive experience on our platform.
            </p>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>Information We Collect</h2>
            <p>
              We collect information you provide directly, such as when you create an account or use our services. This includes:
            </p>
            <ul className={`list-disc list-inside space-y-2 ${isDarkMode ? 'text-gray-400' : 'text-gray-700'}`}>
              <li>Account information (name, email, password)</li>
              <li>Site configuration data</li>
              <li>Camera feeds and safety violation records</li>
              <li>User activity logs</li>
            </ul>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>How We Use Your Information</h2>
            <p>
              We use the information we collect to provide, maintain, and improve our services, including:
            </p>
            <ul className={`list-disc list-inside space-y-2 ${isDarkMode ? 'text-gray-400' : 'text-gray-700'}`}>
              <li>Delivering safety monitoring functionality</li>
              <li>Analyzing and improving system performance</li>
              <li>Communicating with you about your account</li>
              <li>Detecting and preventing fraud or security issues</li>
            </ul>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>Data Protection</h2>
            <p>
              We implement appropriate technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.
            </p>

            <h2 className={`text-xl font-bold mt-6 ${isDarkMode ? 'text-white' : ''}`}>Your Rights</h2>
            <p>
              You have the right to access, modify, or delete your personal information. Contact us if you wish to exercise these rights or have questions about our privacy practices.
            </p>
          </div>
        )}
      </div>

      {/* Acceptance */}
      <div className="max-w-4xl mx-auto">
        <p className={`text-sm mb-3 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
          By using this application, you acknowledge that you have read and understood our{' '}
          {activeTab === 'terms' ? 'Terms of Service' : 'Privacy Policy'}.
        </p>
        <button
          onClick={handleAccept}
          className={`w-full text-white font-semibold py-3 rounded-lg transition ${isDarkMode ? 'bg-blue-700 hover:bg-blue-600' : 'bg-blue-600 hover:bg-blue-700'}`}
        >
          I Understand and Accept
        </button>
      </div>
    </div>
  );
}

export default TermsConditions;
