package org.ohdsi.webapi;

import javax.annotation.PostConstruct;
import org.ohdsi.webapi.service.VocabularyService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.support.SpringBootServletInitializer;

/**
 * Launch as java application or deploy as WAR (@link {@link WebApplication}
 * will source this file).
 */
@SpringBootApplication(exclude = {HibernateJpaAutoConfiguration.class})
public class WebApi extends SpringBootServletInitializer {

    @Autowired
    private VocabularyService vocabularyService;
    
    @Override
    protected SpringApplicationBuilder configure(final SpringApplicationBuilder application) {
        return application.sources(WebApi.class);
    }

    public static void main(final String[] args) throws Exception {
        new SpringApplicationBuilder(WebApi.class).run(args);
    }

    @PostConstruct
    public void loadFullTextIndices() {
        vocabularyService.loadFullTextIndices();
    }
}
