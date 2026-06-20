import React, { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion';
import { HelpCircle, MessageSquare, FileText, AlertCircle, Zap } from 'lucide-react';
import { useTheme } from '@/context/ThemeContext';
import { Link } from 'react-router-dom';

export default function Help() {
  const { isDarkMode } = useTheme();
  const [expandedFaq, setExpandedFaq] = useState<string | null>(null);

  const faqs = [
    {
      id: 'faq-1',
      question: 'How do I view live camera feeds?',
      answer: 'Go to the Dashboard from the top navigation. Click on any zone card under "Live Camera Feeds" to view the live camera feed for that specific zone.'
    },
    {
      id: 'faq-2',
      question: 'What do the alert priority levels mean?',
      answer: 'HIGH Priority: Critical safety violations requiring immediate action. MEDIUM Priority: Important but less urgent violations. LOW Priority: Minor compliance issues.'
    },
    {
      id: 'faq-3',
      question: 'How can I acknowledge an alert?',
      answer: 'Go to the Alerts page from the top navigation. Find the alert you want to acknowledge and click the "Acknowledge" button on the alert card.'
    },
    {
      id: 'faq-4',
      question: 'Where can I view historical data?',
      answer: 'Click on "History" from the top navigation menu to view past alerts, violations, and system events. You can filter by date range or alert type.'
    },
    {
      id: 'faq-5',
      question: 'How do I generate analytics reports?',
      answer: 'Navigate to "Analytics" from the top menu. You can view compliance trends, worker safety scores, and zone-specific statistics over different time periods.'
    },
    {
      id: 'faq-6',
      question: 'Can I adjust notification settings?',
      answer: 'Yes! Go to Settings from the bottom navigation. You can enable/disable push notifications, sound alerts, and email notifications based on your preferences.'
    }
  ];

  const quickLinks = [
    { icon: AlertCircle, title: 'Understanding Alerts', description: 'Learn how to interpret and respond to safety alerts' },
    { icon: Zap, title: 'Quick Tips', description: 'Best practices for using the monitoring system' },
    { icon: FileText, title: 'Documentation', description: 'Complete user guide and technical documentation' }
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className={`text-3xl font-bold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>Help & Support</h1>
        <p className={`mt-1 text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Find answers and get assistance</p>
      </div>

      {/* Quick Links */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {quickLinks.map((link, idx) => {
          const Icon = link.icon;
          return (
            <Card key={idx} className={`shadow-sm cursor-pointer hover:shadow-md transition ${isDarkMode ? 'bg-gray-800 border-gray-700' : ''}`}>
              <CardContent className="pt-6">
                <Icon className="h-8 w-8 text-primary-600 mb-3" />
                <h3 className={`font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>{link.title}</h3>
                <p className={`text-sm mt-2 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>{link.description}</p>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {/* Contact Support */}
      <Card className={`shadow-sm border-2 ${isDarkMode ? 'bg-blue-950 border-blue-800' : 'bg-blue-50 border-blue-100'}`}>
        <CardHeader>
          <CardTitle className={`flex items-center gap-2 ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
            <MessageSquare className="h-5 w-5 text-primary-600" /> Need Immediate Help?
          </CardTitle>
          <CardDescription className={isDarkMode ? 'text-gray-400' : 'text-gray-600'}>Get in touch with our support team</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <div>
            <p className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>Email Support</p>
            <p className={isDarkMode ? 'text-gray-300' : 'text-gray-700'}>support@smartcamera.com</p>
          </div>
          <div>
            <p className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>Phone Support</p>
            <p className={isDarkMode ? 'text-gray-300' : 'text-gray-700'}>+1 (800) 555-SAFE (7233)</p>
          </div>
          <div>
            <p className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>Operating Hours</p>
            <p className={isDarkMode ? 'text-gray-300' : 'text-gray-700'}>Monday - Friday, 8:00 AM - 6:00 PM EST</p>
          </div>
          <Link to="/site/contact-support">
            <Button className="w-full mt-4 bg-indigo-600 hover:bg-indigo-700 text-white">
              <MessageSquare className="mr-2 h-4 w-4" /> Contact Support
            </Button>
          </Link>
        </CardContent>
      </Card>

      {/* FAQ Section */}
      <div>
        <h2 className={`text-xl font-bold mb-4 flex items-center gap-2 ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
          <HelpCircle className="h-6 w-6 text-amber-500" /> Frequently Asked Questions
        </h2>
        <Card className={`shadow-sm ${isDarkMode ? 'bg-gray-800 border-gray-700' : ''}`}>
          <CardContent className="pt-6">
            <Accordion type="single" collapsible className="w-full">
              {faqs.map((faq) => (
                <AccordionItem key={faq.id} value={faq.id} className={`border-${isDarkMode ? 'gray-700' : 'gray-200'}`}>
                  <AccordionTrigger className={`${isDarkMode ? 'text-gray-300 hover:text-primary-400' : 'text-gray-900 hover:text-primary-600'} hover:no-underline`}>
                    {faq.question}
                  </AccordionTrigger>
                  <AccordionContent className={isDarkMode ? 'text-gray-400' : 'text-gray-600'}>
                    {faq.answer}
                  </AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
